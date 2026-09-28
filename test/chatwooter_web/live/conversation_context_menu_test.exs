defmodule ChatwooterWeb.ConversationContextMenuTest do
  use ChatwooterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures
  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes, Repo}
  alias Chatwooter.Conversations.Conversation

  setup %{conn: conn} do
    admin = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Menu"}, admin)
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Sales", channel_type: "whatsapp"})
    {:ok, contact} = Contacts.get_or_create_contact(account, %{name: "Ana"})
    {:ok, conv} = Conversations.open_conversation(account, inbox, contact, %{source_id: "ana"})
    {:ok, _} = Conversations.add_message(conv, %{content: "hello", message_type: :incoming})
    {:ok, _} = Conversations.mark_seen(conv)

    %{conn: log_in_user(conn, admin), admin: admin, account: account, inbox: inbox, conv: conv}
  end

  defp open_menu(ctx) do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#chat-tab-all") |> render_click()

    lv
    |> element("#conv-#{ctx.conv.id}")
    |> render_hook("card:context_menu", %{"id" => ctx.conv.id, "x" => 40, "y" => 80})

    assert has_element?(lv, "#conversation-context-menu")
    lv
  end

  defp reload(conv), do: Repo.get!(Conversation, conv.id)

  test "right click opens the menu at the cursor and Escape closes it", ctx do
    lv = open_menu(ctx)
    assert has_element?(lv, "#conversation-context-menu[style*='left: 40px'][style*='top: 80px']")
    assert has_element?(lv, "#context-menu-mark-unread", "Mark as unread")
    refute has_element?(lv, "#context-menu-mark-read")
    refute has_element?(lv, "#context-menu-status-open")
    assert has_element?(lv, "#context-menu-status-resolved", "Mark as resolved")
    assert has_element?(lv, "#context-menu-status-pending", "Mark as pending")
    assert has_element?(lv, "#context-menu-snooze", "Snooze")

    render_keydown(lv, "card:close_menu", %{"key" => "Escape"})
    refute has_element?(lv, "#conversation-context-menu")
  end

  test "mark as unread and back to read", ctx do
    lv = open_menu(ctx)
    lv |> element("#context-menu-mark-unread") |> render_click()
    refute has_element?(lv, "#conversation-context-menu")
    assert has_element?(lv, "#conv-#{ctx.conv.id} [data-role=unread]", "1")

    lv
    |> element("#conv-#{ctx.conv.id}")
    |> render_hook("card:context_menu", %{"id" => ctx.conv.id, "x" => 1, "y" => 1})

    lv |> element("#context-menu-mark-read") |> render_click()
    refute has_element?(lv, "#conv-#{ctx.conv.id} [data-role=unread]")
  end

  test "status change resolves the conversation", ctx do
    lv = open_menu(ctx)
    lv |> element("#context-menu-status-resolved") |> render_click()
    assert reload(ctx.conv).status == :resolved
    refute has_element?(lv, "#conv-#{ctx.conv.id}")
  end

  test "priority submenu hides the current priority", ctx do
    lv = open_menu(ctx)
    refute has_element?(lv, "#context-menu-priority-none")
    lv |> element("#context-menu-priority-urgent") |> render_click()
    assert reload(ctx.conv).priority == 3

    lv
    |> element("#conv-#{ctx.conv.id}")
    |> render_hook("card:context_menu", %{"id" => ctx.conv.id, "x" => 1, "y" => 1})

    refute has_element?(lv, "#context-menu-priority-urgent")
    lv |> element("#context-menu-priority-none") |> render_click()
    assert reload(ctx.conv).priority == nil
  end

  test "label submenu toggles account labels on the conversation", ctx do
    label =
      Repo.insert!(%Contacts.Label{account_id: ctx.account.id, title: "billing", color: "#f00"})

    lv = open_menu(ctx)
    lv |> element("#context-menu-label-#{label.id}") |> render_click()
    assert Conversations.list_labels(ctx.conv) == ["billing"]
    assert has_element?(lv, "#context-menu-label-#{label.id} .ph-check")

    lv |> element("#context-menu-label-#{label.id}") |> render_click()
    assert Conversations.list_labels(ctx.conv) == []
  end

  test "agent and team submenus assign the conversation", ctx do
    {:ok, team} = Accounts.create_team(ctx.account, %{name: "Support"})
    lv = open_menu(ctx)
    assert has_element?(lv, "#context-menu-agent-none", "None")
    Repo.update!(Ecto.Changeset.change(ctx.admin, name: ""))

    lv
    |> element("#conv-#{ctx.conv.id}")
    |> render_hook("card:context_menu", %{"id" => ctx.conv.id, "x" => 1, "y" => 1})

    assert has_element?(lv, "#context-menu-agent-#{ctx.admin.id}", ctx.admin.email)

    lv |> element("#context-menu-agent-#{ctx.admin.id}") |> render_click()
    assert reload(ctx.conv).assignee_id == ctx.admin.id

    lv
    |> element("#conv-#{ctx.conv.id}")
    |> render_hook("card:context_menu", %{"id" => ctx.conv.id, "x" => 1, "y" => 1})

    lv |> element("#context-menu-team-#{team.id}") |> render_click()
    assert reload(ctx.conv).team_id == team.id
  end

  test "links to open in a new tab and to copy", ctx do
    lv = open_menu(ctx)

    assert has_element?(
             lv,
             "#context-menu-open-new-tab[target=_blank][href$='conversation_id=#{ctx.conv.id}']"
           )

    assert has_element?(
             lv,
             "#context-menu-copy-link[data-copy$='conversation_id=#{ctx.conv.id}']"
           )
  end

  test "administrators delete after confirming", ctx do
    lv = open_menu(ctx)
    lv |> element("#context-menu-delete") |> render_click()

    assert has_element?(
             lv,
             "#delete-conversation-dialog",
             "Delete conversation ##{ctx.conv.display_id}"
           )

    lv |> element("#confirm-delete-conversation") |> render_click()
    refute Repo.get(Conversation, ctx.conv.id)
    refute has_element?(lv, "#conv-#{ctx.conv.id}")
  end

  test "agents do not see delete", ctx do
    agent = user_fixture()
    {:ok, _} = Accounts.add_member(ctx.account, agent, :agent)
    {:ok, _} = Inboxes.add_member(ctx.account, ctx.inbox.id, agent.id)
    lv = open_menu(%{ctx | conn: log_in_user(build_conn(), agent)})
    refute has_element?(lv, "#context-menu-delete")
    render_click(lv, "card:delete", %{})
    refute has_element?(lv, "#delete-conversation-dialog")
  end
end
