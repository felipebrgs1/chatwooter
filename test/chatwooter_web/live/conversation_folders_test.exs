defmodule ChatwooterWeb.ConversationFoldersTest do
  use ChatwooterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures
  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes}
  alias Chatwooter.Accounts.Scope

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Folders"}, user)
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Sales", channel_type: "whatsapp"})
    {:ok, contact} = Contacts.get_or_create_contact(account, %{name: "Resolved customer"})

    {:ok, resolved} =
      Conversations.open_conversation(account, inbox, contact, %{
        source_id: "resolved",
        status: "resolved"
      })

    {:ok, contact} = Contacts.get_or_create_contact(account, %{name: "Open customer"})
    {:ok, open} = Conversations.open_conversation(account, inbox, contact, %{source_id: "open"})

    query = %{
      "payload" => [
        %{"attribute_key" => "status", "filter_operator" => "equal_to", "values" => ["resolved"]}
      ]
    }

    {:ok, folder} =
      Accounts.create_custom_filter(Scope.for_user(user), account, %{
        name: "Resolved folder",
        query: query
      })

    %{
      conn: log_in_user(conn, user),
      user: user,
      account: account,
      folder: folder,
      resolved: resolved,
      open: open
    }
  end

  test "sidebar links to private folders and the folder overrides the basic open status", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app?folder_id=#{ctx.folder.id}")
    assert has_element?(lv, "a[href='/app?folder_id=#{ctx.folder.id}']", "Resolved folder")
    assert has_element?(lv, "#chat-list-header h1", "Resolved folder")
    refute has_element?(lv, "#chat-list-status")
    refute has_element?(lv, "#chat-status-select")
    lv |> element("#chat-tab-all") |> render_click()
    assert has_element?(lv, "#conv-#{ctx.resolved.id}[href*='folder_id=']")
    refute has_element?(lv, "#conv-#{ctx.open.id}")
  end

  test "another member cannot access the owner's folder", ctx do
    other = user_fixture()
    {:ok, _} = Accounts.add_member(ctx.account, other, :agent)
    conn = log_in_user(build_conn(), other)
    {:ok, lv, _} = live(conn, ~p"/app?folder_id=#{ctx.folder.id}")
    refute has_element?(lv, "a[href='/app?folder_id=#{ctx.folder.id}']")
    assert has_element?(lv, "#chat-list-header h1", "Conversations")
    assert render(lv) =~ "Folder not found"
  end

  test "apply, save, rename and delete a folder through the screen", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    assert has_element?(lv, "#conversation-filter-editor", "Filter conversations")

    lv |> element("#condition-values-0-option-resolved") |> render_click()
    lv |> form("#conversation-filter-form") |> render_submit()

    lv |> element("#chat-tab-all") |> render_click()
    assert has_element?(lv, "#conv-#{ctx.resolved.id}")
    refute has_element?(lv, "#conv-#{ctx.open.id}")
    lv |> element("#save-conversation-filter") |> render_click()

    lv
    |> form("#save-filter-form", %{"folder" => %{"name" => "My resolved tickets"}})
    |> render_submit()

    assert has_element?(lv, "#chat-list-header h1", "My resolved tickets")

    [folder] =
      Enum.filter(
        Accounts.list_custom_filters(Scope.for_user(ctx.user), ctx.account),
        &(&1.name == "My resolved tickets")
      )

    assert has_element?(lv, "a[href='/app?folder_id=#{folder.id}']")
    lv |> element("#toggleConversationFilterButton") |> render_click()

    lv
    |> form("#conversation-filter-form", %{"filters" => %{"name" => "Renamed folder"}})
    |> render_submit()

    assert has_element?(lv, "#chat-list-header h1", "Renamed folder")
    lv |> element("#delete-conversation-folder") |> render_click()
    assert has_element?(lv, "#delete-filter-confirmation", "Confirm deletion")
    lv |> element("#confirm-delete-filter") |> render_click()
    refute has_element?(lv, "a[href='/app?folder_id=#{folder.id}']")
    assert nil == Accounts.get_custom_filter(Scope.for_user(ctx.user), ctx.account, folder.id)
  end

  test "editor and save form open as popovers anchored to their header buttons", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    assert has_element?(lv, "#conversationFilterTeleportTarget #conversation-filter-editor")
    refute has_element?(lv, "#conversation-filter-editor button", "Cancel")

    lv |> element("#condition-values-0-option-resolved") |> render_click()
    lv |> form("#conversation-filter-form") |> render_submit()
    refute has_element?(lv, "#conversation-filter-editor")

    lv |> element("#save-conversation-filter") |> render_click()
    assert has_element?(lv, "#saveFilterTeleportTarget #save-filter-form")
  end

  test "the back button in the header clears applied filters", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#condition-values-0-option-resolved") |> render_click()
    lv |> form("#conversation-filter-form") |> render_submit()
    lv |> element("#chat-tab-all") |> render_click()
    refute has_element?(lv, "#conv-#{ctx.open.id}")

    lv |> element("#reset-conversation-filters") |> render_click()
    assert_patch(lv, ~p"/app")
    refute has_element?(lv, "#reset-conversation-filters")
    refute has_element?(lv, "#save-conversation-filter")
    lv |> element("#chat-tab-all") |> render_click()
    assert has_element?(lv, "#conv-#{ctx.open.id}")
  end

  test "removing the only condition and applying clears the applied filter", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#condition-values-0-option-resolved") |> render_click()
    lv |> form("#conversation-filter-form") |> render_submit()

    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#remove-condition-0") |> render_click()
    lv |> form("#conversation-filter-form") |> render_submit()

    assert_patch(lv, ~p"/app")
    refute has_element?(lv, "#conversation-filter-error")
    refute has_element?(lv, "#reset-conversation-filters")
  end

  test "a folder still needs a condition", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app?folder_id=#{ctx.folder.id}")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#remove-condition-0") |> render_click()
    lv |> form("#conversation-filter-form") |> render_submit()
    assert has_element?(lv, "#conversation-filter-error", "Value is required")
  end

  test "folders have no back button; they are left through the sidebar", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app?folder_id=#{ctx.folder.id}")
    refute has_element?(lv, "#reset-conversation-filters")
  end

  test "invalid filters keep the editor open and do not replace the current results", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()

    lv
    |> form("#conversation-filter-form", %{"filters" => %{"rows" => %{"0" => %{"values" => ""}}}})
    |> render_submit()

    assert has_element?(lv, "#conversation-filter-editor")
    assert has_element?(lv, "#conversation-filter-error", "Value is required")
    refute has_element?(lv, "#save-conversation-filter")
  end

  test "searchable pickers change a condition without submitting the filter", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    assert has_element?(lv, "#condition-attribute-0 input[type=search]")
    assert has_element?(lv, "#condition-attribute-0-group-standard", "Standard filters")
    assert has_element?(lv, "#condition-attribute-0-group-additional", "Additional filters")
    refute has_element?(lv, "#condition-attribute-0-group-standard[role=option]")
    assert has_element?(lv, "#condition-attribute-0-option-status .ph-record")
    lv |> element("#condition-attribute-0-option-referer") |> render_click()
    assert has_element?(lv, "input[name='filters[rows][0][attribute_key]'][value=referer]")
    lv |> element("#condition-operator-0-option-contains") |> render_click()
    assert has_element?(lv, "input[name='filters[rows][0][filter_operator]'][value=contains]")
    assert has_element?(lv, "#conversation-filter-editor")
    refute has_element?(lv, "#save-conversation-filter")
  end

  test "status values use a multi-picker and preserve two selections", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    assert has_element?(lv, "#condition-values-0-option-resolved")
    lv |> element("#condition-values-0-option-resolved") |> render_click()
    lv |> element("#condition-values-0-option-open") |> render_click()
    assert has_element?(lv, "#condition-values-0-chip-resolved")
    assert has_element?(lv, "#condition-values-0-chip-open")
    lv |> form("#conversation-filter-form") |> render_submit()
    lv |> element("#chat-tab-all") |> render_click()
    assert has_element?(lv, "#conv-#{ctx.resolved.id}")
    assert has_element?(lv, "#conv-#{ctx.open.id}")
  end

  test "label picker keeps a title containing a comma as one value", ctx do
    Chatwooter.Repo.insert!(%Contacts.Label{
      account_id: ctx.account.id,
      title: "Sales, VIP",
      color: "#123456"
    })

    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#condition-attribute-0-option-labels") |> render_click()
    assert has_element?(lv, "[id='condition-values-0-option-Sales, VIP']")
    lv |> element("[id='condition-values-0-option-Sales, VIP']") |> render_click()
    assert has_element?(lv, "[id='condition-values-0-chip-Sales, VIP']")
    assert has_element?(lv, "#filter-row-0_values[value*='Sales, VIP']")
    lv |> form("#conversation-filter-form") |> render_submit()
    assert has_element?(lv, "#save-conversation-filter")
  end

  test "inbox picker shows only account inboxes and applies selected ID", ctx do
    other_user = user_fixture()
    {:ok, other_account} = Accounts.create_account(%{name: "Other"}, other_user)

    {:ok, other_inbox} =
      Inboxes.create_inbox(other_account, %{name: "Private", channel_type: "whatsapp"})

    [inbox] = Inboxes.list_inboxes(ctx.account)

    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#condition-attribute-0-option-inbox_id") |> render_click()
    assert has_element?(lv, "#condition-values-0-option-#{inbox.id}", "Sales")
    refute has_element?(lv, "#condition-values-0-option-#{other_inbox.id}")
    lv |> element("#condition-values-0-option-#{inbox.id}") |> render_click()
    assert has_element?(lv, "#filter-row-0_values[value='#{inbox.id}']")
    lv |> form("#conversation-filter-form") |> render_submit()
    lv |> element("#chat-tab-all") |> render_click()
    assert has_element?(lv, "#conv-#{ctx.resolved.id}")
    assert has_element?(lv, "#conv-#{ctx.open.id}")
  end

  test "contact search is scoped to the account and can select a name-only contact", ctx do
    other_user = user_fixture()
    {:ok, other_account} = Accounts.create_account(%{name: "Other contacts"}, other_user)
    {:ok, private} = Contacts.get_or_create_contact(other_account, %{name: "Private customer"})
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#condition-attribute-0-option-contact_id") |> render_click()
    render_hook(lv, "filter:search_contact", %{"index" => 0, "query" => "customer"})
    assert has_element?(lv, "#condition-values-0-option-#{ctx.resolved.contact_id}")
    assert has_element?(lv, "#condition-values-0-option-#{ctx.open.contact_id}")
    refute has_element?(lv, "#condition-values-0-option-#{private.id}")
    lv |> element("#condition-values-0-option-#{ctx.resolved.contact_id}") |> render_click()
    assert has_element?(lv, "#filter-row-0_values[value='#{ctx.resolved.contact_id}']")
    lv |> form("#conversation-filter-form") |> render_submit()
    lv |> element("#chat-tab-all") |> render_click()
    assert has_element?(lv, "#conv-#{ctx.resolved.id}")
    refute has_element?(lv, "#conv-#{ctx.open.id}")
  end

  test "campaign picker contains only campaigns from the account", ctx do
    alias Chatwooter.Automations.Campaign
    alias Chatwooter.Repo

    [inbox] = Inboxes.list_inboxes(ctx.account)
    now = DateTime.utc_now() |> DateTime.to_naive()

    campaign =
      Repo.insert!(%Campaign{
        account_id: ctx.account.id,
        inbox_id: inbox.id,
        title: "September follow-up",
        message: "Hello",
        created_at: now,
        updated_at: now
      })

    other_user = user_fixture()
    {:ok, other_account} = Accounts.create_account(%{name: "Other campaigns"}, other_user)

    {:ok, other_inbox} =
      Inboxes.create_inbox(other_account, %{name: "Private", channel_type: "whatsapp"})

    private =
      Repo.insert!(%Campaign{
        account_id: other_account.id,
        inbox_id: other_inbox.id,
        title: "Private campaign",
        message: "Private",
        created_at: now,
        updated_at: now
      })

    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#condition-attribute-0-option-campaign_id") |> render_click()
    assert has_element?(lv, "#condition-values-0-option-#{campaign.id}", "September follow-up")
    refute has_element?(lv, "#condition-values-0-option-#{private.id}")
    lv |> element("#condition-values-0-option-#{campaign.id}") |> render_click()
    assert has_element?(lv, "#filter-row-0_values[value='#{campaign.id}']")
    lv |> form("#conversation-filter-form") |> render_submit()
    assert has_element?(lv, "#save-conversation-filter")
  end

  test "browser language uses the upstream searchable language list", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#condition-attribute-0-option-browser_language") |> render_click()
    assert has_element?(lv, "#condition-values-0-option-en", "English")
    assert has_element?(lv, "#condition-values-0-option-pt", "Portuguese")
    lv |> element("#condition-values-0-option-en") |> render_click()
    assert has_element?(lv, "#filter-row-0_values[value='en']")
    lv |> form("#conversation-filter-form") |> render_submit()
    assert has_element?(lv, "#save-conversation-filter")
  end

  test "presence operators hide values and restore the picker on equality", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#condition-attribute-0-option-assignee_id") |> render_click()
    lv |> element("#condition-values-0-option-#{ctx.user.id}") |> render_click()
    lv |> element("#condition-operator-0-option-is_present") |> render_click()
    refute has_element?(lv, "#condition-values-0")
    assert has_element?(lv, "#filter-row-0_values[type=hidden][value='#{ctx.user.id}']")
    lv |> element("#condition-operator-0-option-equal_to") |> render_click()
    assert has_element?(lv, "#condition-values-0-option-#{ctx.user.id}")
    assert has_element?(lv, "#filter-row-0_values[value='#{ctx.user.id}']")
  end

  test "multiple conditions preserve the preceding connector and removal resets the last row",
       ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#add-filter-condition") |> render_click()
    assert has_element?(lv, "#condition-row-1")

    lv |> element("#condition-values-0-option-open") |> render_click()
    lv |> element("#condition-values-1-option-resolved") |> render_click()

    refute has_element?(lv, "#condition-join-1 input[type=search]")
    lv |> element("#condition-join-1-option-or") |> render_click()
    lv |> form("#conversation-filter-form") |> render_submit()

    lv |> element("#chat-tab-all") |> render_click()
    assert has_element?(lv, "#conv-#{ctx.resolved.id}")
    assert has_element?(lv, "#conv-#{ctx.open.id}")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    assert has_element?(lv, "input[name='filters[rows][0][query_operator]'][value=or]")
    lv |> element("#remove-condition-1") |> render_click()
    lv |> element("#remove-condition-0") |> render_click()
    assert has_element?(lv, "#filter-row-0_values[value='']")
    refute has_element?(lv, "#condition-row-1")
  end

  test "clear resets the draft without changing the saved folder", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app?folder_id=#{ctx.folder.id}")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#clear-conversation-filters") |> render_click()
    assert has_element?(lv, "#conversation-filter-form")
    assert has_element?(lv, "#filter-row-0_values[value='']")
    assert has_element?(lv, "#filters_name[value='Resolved folder']")

    assert Accounts.get_custom_filter(Scope.for_user(ctx.user), ctx.account, ctx.folder.id).query ==
             ctx.folder.query
  end

  test "additional attribute filters can be edited and saved from the screen", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app?folder_id=#{ctx.folder.id}")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    assert has_element?(lv, "#condition-attribute-0-option-referer", "Referer link")

    lv |> element("#condition-attribute-0-option-referer") |> render_click()

    assert has_element?(lv, "#condition-operator-0-option-contains")
    refute has_element?(lv, "#condition-operator-0-option-is_present")
    lv |> element("#condition-operator-0-option-contains") |> render_click()

    lv
    |> form("#conversation-filter-form", %{
      "filters" => %{
        "rows" => %{"0" => %{"filter_operator" => "contains", "values" => "example.com"}}
      }
    })
    |> render_submit()

    assert Accounts.get_custom_filter(Scope.for_user(ctx.user), ctx.account, ctx.folder.id).query ==
             %{
               "payload" => [
                 %{
                   "attribute_key" => "referer",
                   "filter_operator" => "contains",
                   "values" => ["example.com"]
                 }
               ]
             }
  end

  test "referer text keeps a literal comma as one filter value", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#condition-attribute-0-option-referer") |> render_click()
    lv |> element("#condition-operator-0-option-contains") |> render_click()

    lv
    |> form("#conversation-filter-form", %{
      "filters" => %{"rows" => %{"0" => %{"values" => "https://example.com/a,b"}}}
    })
    |> render_submit()

    path = assert_patch(lv)

    query =
      path
      |> URI.parse()
      |> Map.fetch!(:query)
      |> URI.decode_query()
      |> Map.fetch!("filters")
      |> Jason.decode!()

    assert query["payload"] |> hd() |> Map.fetch!("values") == ["https://example.com/a,b"]
  end

  test "date editor preserves a saved timezone through rename and reload", ctx do
    query = %{
      "payload" => [
        %{
          "attribute_key" => "created_at",
          "filter_operator" => "is_less_than",
          "values" => ["2030-01-01"],
          "timezone" => "Europe/Berlin"
        }
      ]
    }

    {:ok, folder} =
      Accounts.update_custom_filter(Scope.for_user(ctx.user), ctx.account, ctx.folder.id, %{
        query: query
      })

    {:ok, lv, _} = live(ctx.conn, ~p"/app?folder_id=#{folder.id}")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    assert has_element?(lv, "#filter-row-0_values[type=date][value='2030-01-01']")
    assert has_element?(lv, "input[name='filters[rows][0][timezone]'][value='Europe/Berlin']")
    refute has_element?(lv, "#condition-operator-0-option-equal_to")

    lv
    |> form("#conversation-filter-form", %{"filters" => %{"name" => "Before 2030"}})
    |> render_submit()

    assert Accounts.get_custom_filter(Scope.for_user(ctx.user), ctx.account, folder.id).query ==
             query
  end

  test "custom definitions cannot override a standard conversation attribute", ctx do
    alias Chatwooter.Repo

    Repo.insert!(%Contacts.CustomAttributeDefinition{
      account_id: ctx.account.id,
      attribute_key: "status",
      attribute_display_name: "Custom status",
      attribute_model: :conversation_attribute,
      attribute_display_type: :date
    })

    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    assert has_element?(lv, "#condition-attribute-0-option-status", "Status")
    refute has_element?(lv, "#condition-attribute-0 [role=option]", "Custom status")
    assert has_element?(lv, "#condition-values-0-option-open")
    refute has_element?(lv, "#condition-operator-0-option-is_less_than")

    lv |> element("#condition-values-0-option-open") |> render_click()
    lv |> element("#condition-values-0-option-resolved") |> render_click()
    lv |> form("#conversation-filter-form") |> render_submit()

    lv |> element("#chat-tab-all") |> render_click()
    assert has_element?(lv, "#conv-#{ctx.open.id}")
    assert has_element?(lv, "#conv-#{ctx.resolved.id}")
  end

  test "custom date, number, list and checkbox inputs use their declared types", ctx do
    alias Chatwooter.Repo

    for {key, type} <- [{"amount", :number}, {"paid", :checkbox}, {"due", :date}, {"tier", :list}] do
      Repo.insert!(%Contacts.CustomAttributeDefinition{
        account_id: ctx.account.id,
        attribute_key: key,
        attribute_display_name: key,
        attribute_model: :conversation_attribute,
        attribute_display_type: type,
        attribute_values: ["Gold", "Silver"]
      })
    end

    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()

    for key <- ["amount", "due", "paid", "tier"] do
      lv |> element("#condition-attribute-0-option-#{key}") |> render_click()

      case key do
        "amount" ->
          assert has_element?(lv, "#filter-row-0_values[type=number][step=any]")

        "due" ->
          assert has_element?(lv, "#filter-row-0_values[type=date]")
          assert has_element?(lv, "#condition-operator-0-option-is_greater_than")

        "paid" ->
          assert has_element?(lv, "#condition-values-0-option-false", "False")

        "tier" ->
          assert has_element?(lv, "#condition-values-0-option-Gold", "Gold")
      end
    end
  end

  test "custom list and checkbox values use pickers and filter results", ctx do
    alias Chatwooter.Repo

    for {key, type, values} <- [{"tier", :list, ["Gold", "Silver"]}, {"paid", :checkbox, []}] do
      Repo.insert!(%Contacts.CustomAttributeDefinition{
        account_id: ctx.account.id,
        attribute_key: key,
        attribute_display_name: key,
        attribute_model: :conversation_attribute,
        attribute_display_type: type,
        attribute_values: values
      })
    end

    Repo.update!(
      Ecto.Changeset.change(ctx.resolved, custom_attributes: %{"tier" => "Gold", "paid" => true})
    )

    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#condition-attribute-0-option-tier") |> render_click()
    assert has_element?(lv, "#condition-values-0-option-Gold")
    lv |> element("#condition-values-0-option-Gold") |> render_click()
    lv |> form("#conversation-filter-form") |> render_submit()
    lv |> element("#chat-tab-all") |> render_click()
    assert has_element?(lv, "#conv-#{ctx.resolved.id}")
    refute has_element?(lv, "#conv-#{ctx.open.id}")

    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#condition-attribute-0-option-paid") |> render_click()
    assert has_element?(lv, "#condition-values-0-option-true")
    lv |> element("#condition-values-0-option-true") |> render_click()
    lv |> form("#conversation-filter-form") |> render_submit()
    lv |> element("#chat-tab-all") |> render_click()
    assert has_element?(lv, "#conv-#{ctx.resolved.id}")
    refute has_element?(lv, "#conv-#{ctx.open.id}")
  end

  test "custom conversation attributes appear in the editor and survive saved-folder reload",
       ctx do
    alias Chatwooter.Repo

    Repo.insert!(%Contacts.CustomAttributeDefinition{
      account_id: ctx.account.id,
      attribute_key: "plan",
      attribute_display_name: "Support plan",
      attribute_model: :conversation_attribute
    })

    Repo.insert!(%Contacts.CustomAttributeDefinition{
      account_id: ctx.account.id,
      attribute_key: "internal_contact",
      attribute_display_name: "Contact only",
      attribute_model: :contact_attribute
    })

    Repo.update!(Ecto.Changeset.change(ctx.resolved, custom_attributes: %{"plan" => "GOLD"}))
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    assert has_element?(lv, "#condition-attribute-0-group-customAttributes", "Custom attributes")
    assert has_element?(lv, "#condition-attribute-0-option-plan .ph-text-t")
    assert has_element?(lv, "#condition-attribute-0-option-plan", "Support plan")
    refute has_element?(lv, "#condition-attribute-0-option-internal_contact")

    lv |> element("#condition-attribute-0-option-plan") |> render_click()

    assert has_element?(lv, "#condition-operator-0-option-contains")

    lv
    |> form("#conversation-filter-form", %{
      "filters" => %{"rows" => %{"0" => %{"values" => "gold"}}}
    })
    |> render_submit()

    lv |> element("#chat-tab-all") |> render_click()
    assert has_element?(lv, "#conv-#{ctx.resolved.id}")
    refute has_element?(lv, "#conv-#{ctx.open.id}")
    lv |> element("#save-conversation-filter") |> render_click()

    lv
    |> form("#save-filter-form", %{"folder" => %{"name" => "Gold customers"}})
    |> render_submit()

    assert has_element?(lv, "#chat-list-header h1", "Gold customers")

    folder =
      Enum.find(
        Accounts.list_custom_filters(Scope.for_user(ctx.user), ctx.account),
        &(&1.name == "Gold customers")
      )

    {:ok, reloaded, _} = live(ctx.conn, ~p"/app?folder_id=#{folder.id}")
    reloaded |> element("#chat-tab-all") |> render_click()
    assert has_element?(reloaded, "#conv-#{ctx.resolved.id}")
  end

  test "cancel deletion preserves the folder and blank rename cannot change it", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app?folder_id=#{ctx.folder.id}")
    lv |> element("#delete-conversation-folder") |> render_click()
    lv |> element("#delete-filter-confirmation button", "No, keep it") |> render_click()
    refute has_element?(lv, "#delete-filter-confirmation")
    assert Accounts.get_custom_filter(Scope.for_user(ctx.user), ctx.account, ctx.folder.id)
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> form("#conversation-filter-form", %{"filters" => %{"name" => ""}}) |> render_submit()
    assert has_element?(lv, "#conversation-filter-error", "Name is required")

    assert Accounts.get_custom_filter(Scope.for_user(ctx.user), ctx.account, ctx.folder.id).name ==
             "Resolved folder"
  end
end
