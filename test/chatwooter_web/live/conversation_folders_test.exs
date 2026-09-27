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

    lv
    |> form("#conversation-filter-form", %{
      "filters" => %{
        "rows" => %{
          "0" => %{
            "attribute_key" => "status",
            "filter_operator" => "equal_to",
            "values" => "resolved"
          }
        }
      }
    })
    |> render_submit()

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

  test "multiple conditions preserve the preceding connector and removal resets the last row",
       ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    lv |> element("#add-filter-condition") |> render_click()
    assert has_element?(lv, "#condition-row-1")

    lv
    |> form("#conversation-filter-form", %{
      "filters" => %{
        "rows" => %{
          "0" => %{"values" => "open", "query_operator" => "or"},
          "1" => %{"values" => "resolved"}
        }
      }
    })
    |> render_submit()

    lv |> element("#chat-tab-all") |> render_click()
    assert has_element?(lv, "#conv-#{ctx.resolved.id}")
    assert has_element?(lv, "#conv-#{ctx.open.id}")
    lv |> element("#toggleConversationFilterButton") |> render_click()
    assert has_element?(lv, "#condition-join-1 option[value=or][selected]")
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
    assert has_element?(lv, "#condition-attribute-0 option[value=referer]", "Referer link")

    lv
    |> form("#conversation-filter-form", %{
      "filters" => %{"rows" => %{"0" => %{"attribute_key" => "referer"}}}
    })
    |> render_change()

    assert has_element?(lv, "#condition-operator-0 option[value=contains]")
    refute has_element?(lv, "#condition-operator-0 option[value=is_present]")

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
    refute has_element?(lv, "#condition-operator-0 option[value=equal_to]")

    lv
    |> form("#conversation-filter-form", %{"filters" => %{"name" => "Before 2030"}})
    |> render_submit()

    assert Accounts.get_custom_filter(Scope.for_user(ctx.user), ctx.account, folder.id).query ==
             query
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
