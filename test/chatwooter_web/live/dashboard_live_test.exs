defmodule ChatwooterWeb.DashboardLiveTest do
  use ChatwooterWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures
  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes}

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, user)
    %{conn: log_in_user(conn, user), user: user, account: account}
  end

  test "redirects guests to login" do
    assert {:error, {:redirect, %{to: "/app/login"}}} = live(build_conn(), ~p"/app")
  end

  test "lists conversations and sends a reply", %{conn: conn, account: account} do
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    {:ok, contact} =
      Contacts.get_or_create_contact(account, %{name: "Maria", phone_number: "+5511987654321"})

    {:ok, conv} =
      Conversations.open_conversation(account, inbox, contact, %{source_id: "5511987654321"})

    {:ok, _} = Conversations.add_message(conv, %{content: "Olá", message_type: "incoming"})

    {:ok, lv, html} = live(conn, ~p"/app")
    assert html =~ "Maria"
    assert html =~ "Olá"

    html =
      lv
      |> element("#conv-#{conv.id}")
      |> render_click()

    assert html =~ "via Vendas"

    lv
    |> form("#composer", message: %{content: "Oi, Maria!"})
    |> render_submit()

    assert render(lv) =~ "Oi, Maria!"
  end

  test "shows empty state without conversations", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/app")
    assert html =~ "No conversations yet"
  end
end
