defmodule ChatwooterWeb.ChatListTest do
  use ChatwooterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes, Repo}

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, user)
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})
    %{conn: log_in_user(conn, user), user: user, account: account, inbox: inbox}
  end

  defp conversation(account, inbox, name, attrs \\ []) do
    {:ok, contact} = Contacts.get_or_create_contact(account, %{name: name})
    {:ok, conv} = Conversations.open_conversation(account, inbox, contact, %{source_id: name})
    conv |> Ecto.Changeset.change(attrs) |> Repo.update!()
  end

  test "header shows the page title and the active status", %{
    conn: conn,
    account: account,
    inbox: inbox
  } do
    {:ok, lv, _html} = live(conn, ~p"/app")
    assert has_element?(lv, "#chat-list-header h1", "Conversations")
    assert has_element?(lv, "#chat-list-status", "Open")

    {:ok, lv, _html} = live(conn, ~p"/app?inbox_id=#{inbox.id}")
    assert has_element?(lv, "#chat-list-header h1", "Vendas")
    _ = account
  end

  test "starts on the Mine tab and switches between assignee tabs", %{
    conn: conn,
    user: user,
    account: account,
    inbox: inbox
  } do
    mine = conversation(account, inbox, "Maria", assignee_id: user.id)
    unassigned = conversation(account, inbox, "João")

    {:ok, lv, _html} = live(conn, ~p"/app")

    assert has_element?(lv, "#chat-tab-me[aria-selected=true]", "1")
    assert has_element?(lv, "#chat-tab-unassigned", "1")
    assert has_element?(lv, "#chat-tab-all", "2")
    assert has_element?(lv, "#conv-#{mine.id}")
    refute has_element?(lv, "#conv-#{unassigned.id}")

    lv |> element("#chat-tab-unassigned") |> render_click()
    assert has_element?(lv, "#conv-#{unassigned.id}")
    refute has_element?(lv, "#conv-#{mine.id}")

    lv |> element("#chat-tab-all") |> render_click()
    assert has_element?(lv, "#conv-#{mine.id}")
    assert has_element?(lv, "#conv-#{unassigned.id}")
  end

  test "tab survives switching inboxes from the sidebar", %{
    conn: conn,
    account: account,
    inbox: inbox
  } do
    conv = conversation(account, inbox, "João")
    {:ok, lv, _html} = live(conn, ~p"/app")

    lv |> element("#chat-tab-unassigned") |> render_click()
    lv |> element("#sidebar-inbox-#{inbox.id}") |> render_click()

    assert has_element?(lv, "#chat-tab-unassigned[aria-selected=true]")
    assert has_element?(lv, "#conv-#{conv.id}")
  end

  test "status and sort come from the sort menu and are remembered", %{
    conn: conn,
    user: user,
    account: account,
    inbox: inbox
  } do
    resolved = conversation(account, inbox, "Ana", assignee_id: user.id, status: :resolved)
    {:ok, lv, _html} = live(conn, ~p"/app")
    refute has_element?(lv, "#conv-#{resolved.id}")

    lv |> element("#chat-status-option-resolved") |> render_click()
    assert has_element?(lv, "#chat-list-status", "Resolved")
    assert has_element?(lv, "#conv-#{resolved.id}")

    lv |> element("#chat-sort-option-created_at_asc") |> render_click()
    assert has_element?(lv, "#chat-sort-option-created_at_asc[aria-selected=true]")

    assert %{"status" => "resolved", "order_by" => "created_at_asc"} =
             Accounts.get_user!(user.id).ui_settings["conversations_filter_by"]

    {:ok, lv, _html} = live(conn, ~p"/app")
    assert has_element?(lv, "#chat-list-status", "Resolved")
  end

  test "card shows contact, last message preview, time and unread badge", %{
    conn: conn,
    user: user,
    account: account,
    inbox: inbox
  } do
    conv = conversation(account, inbox, "Maria Silva", assignee_id: user.id)
    {:ok, _} = Conversations.add_message(conv, %{content: "Olá, tudo bem?"})

    {:ok, lv, _html} = live(conn, ~p"/app")

    assert has_element?(lv, "#conv-#{conv.id} h4", "Maria Silva")
    assert has_element?(lv, "#conv-#{conv.id} [data-role=preview]", "Olá, tudo bem?")
    assert has_element?(lv, "#conv-#{conv.id} [data-role=time]", "now")
    assert has_element?(lv, "#conv-#{conv.id} [data-role=unread]", "1")

    lv |> element("#conv-#{conv.id}") |> render_click()
    refute has_element?(lv, "#conv-#{conv.id} [data-role=unread]")
    assert has_element?(lv, "#conv-#{conv.id}.active")
  end

  test "shows inbox names only when listing several inboxes", %{
    conn: conn,
    user: user,
    account: account,
    inbox: inbox
  } do
    conv = conversation(account, inbox, "Maria", assignee_id: user.id)

    {:ok, lv, _html} = live(conn, ~p"/app")
    refute has_element?(lv, "#conv-#{conv.id} [data-role=inbox]")

    {:ok, _} = Inboxes.create_inbox(account, %{name: "Suporte", channel_type: "telegram"})
    {:ok, lv, _html} = live(conn, ~p"/app")
    assert has_element?(lv, "#conv-#{conv.id} [data-role=inbox]", "Vendas")

    {:ok, lv, _html} = live(conn, ~p"/app?inbox_id=#{inbox.id}")
    refute has_element?(lv, "#conv-#{conv.id} [data-role=inbox]")
  end

  test "empty and end-of-list messages", %{conn: conn, user: user, account: account, inbox: inbox} do
    {:ok, lv, _html} = live(conn, ~p"/app")
    assert has_element?(lv, "#chat-list-empty")
    refute has_element?(lv, "#chat-list-eof")

    conversation(account, inbox, "Maria", assignee_id: user.id)
    {:ok, lv, _html} = live(conn, ~p"/app")
    refute has_element?(lv, "#chat-list-empty")
    assert has_element?(lv, "#chat-list-eof")
  end
end
