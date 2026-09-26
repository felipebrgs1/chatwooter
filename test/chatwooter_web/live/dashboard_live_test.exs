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

  test "renders image attachments in the thread", %{conn: conn, account: account} do
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "TG", channel_type: "telegram"})
    {:ok, contact} = Contacts.get_or_create_contact(account, %{name: "Maria"})

    {:ok, conv} =
      Conversations.open_conversation(account, inbox, contact, %{source_id: "555"})

    {:ok, message} =
      Conversations.add_message(conv, %{
        content: "olha",
        content_type: "image",
        message_type: "incoming"
      })

    {:ok, _} =
      Conversations.create_attachment(message, %{
        file_type: "image",
        key: "telegram/1/2/f1.jpg",
        url: "http://localhost:9000/chatwooter-dev/telegram/1/2/f1.jpg"
      })

    {:ok, lv, _html} = live(conn, ~p"/app")

    lv
    |> element("#conv-#{conv.id}")
    |> render_click()

    html = render(lv)
    assert html =~ "olha"
    assert html =~ "<img"
    assert html =~ "f1.jpg"
  end

  test "sends a reply to telegram and stores the external id", %{conn: conn, account: account} do
    bypass = Bypass.open()

    Application.put_env(
      :chatwooter,
      :telegram_api_base,
      "http://localhost:#{bypass.port}"
    )

    on_exit(fn -> Application.delete_env(:chatwooter, :telegram_api_base) end)

    Bypass.expect_once(bypass, "POST", "/bottest-token/sendMessage", fn conn ->
      {:ok, _body, conn} = Plug.Conn.read_body(conn)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(
        200,
        Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 77}})
      )
    end)

    {:ok, inbox} =
      Inboxes.create_inbox(account, %{
        name: "TG",
        channel_type: "telegram",
        provider_config: %{"bot_token" => "test-token"}
      })

    {:ok, contact} = Contacts.get_or_create_contact(account, %{name: "Maria"})

    {:ok, conv} =
      Conversations.open_conversation(account, inbox, contact, %{source_id: "555"})

    {:ok, lv, _html} = live(conn, ~p"/app")

    lv
    |> element("#conv-#{conv.id}")
    |> render_click()

    lv
    |> form("#composer", message: %{content: "Oi!"})
    |> render_submit()

    assert render(lv) =~ "Oi!"

    assert [%{source_id: "77"}] =
             Conversations.get_conversation!(account, conv.id).messages
  end
end
