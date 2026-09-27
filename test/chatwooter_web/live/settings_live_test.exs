defmodule ChatwooterWeb.SettingsLiveTest do
  use ChatwooterWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures

  alias Chatwooter.{Accounts, Inboxes}

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, user)
    %{conn: log_in_user(conn, user), user: user, account: account}
  end

  test "redirects guests to login" do
    assert {:error, {:redirect, %{to: "/app/login"}}} = live(build_conn(), ~p"/app/settings")
  end

  test "updates the account name", %{conn: conn, account: account} do
    {:ok, lv, _html} = live(conn, ~p"/app/settings")

    html =
      lv
      |> form("#account-form", account: %{name: "Acme Inc"})
      |> render_submit()

    assert html =~ "Account updated"
    assert html =~ "Acme Inc"
    assert Chatwooter.Repo.get!(Chatwooter.Accounts.Account, account.id).name == "Acme Inc"
  end

  test "configures the telegram bot token", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app/settings/inboxes")

    lv
    |> form("#inbox-form", inbox: %{name: "TG", channel_type: "telegram"})
    |> render_submit()

    lv
    |> element("button[phx-click='edit-inbox']")
    |> render_click()

    html =
      lv
      |> form("#inbox-edit-form", inbox: %{provider_config: %{bot_token: "123:ABC"}})
      |> render_submit()

    assert html =~ "Inbox updated"
    assert html =~ "Configured"
  end

  test "tests the telegram connection and stores the bot username", %{
    conn: conn,
    account: account
  } do
    bypass = Bypass.open()

    Application.put_env(:chatwooter, :telegram_api_base, "http://localhost:#{bypass.port}")
    on_exit(fn -> Application.delete_env(:chatwooter, :telegram_api_base) end)

    Bypass.expect_once(bypass, "GET", "/bottest-token/getMe", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(
        200,
        Jason.encode!(%{
          "ok" => true,
          "result" => %{"id" => 123, "first_name" => "Acme", "username" => "acme_bot"}
        })
      )
    end)

    {:ok, lv, _html} = live(conn, ~p"/app/settings/inboxes")

    lv
    |> form("#inbox-form", inbox: %{name: "TG", channel_type: "telegram"})
    |> render_submit()

    lv |> element("button[phx-click='edit-inbox']") |> render_click()

    lv
    |> form("#inbox-edit-form", inbox: %{name: "TG", provider_config: %{bot_token: "test-token"}})
    |> render_submit()

    lv |> element("button[phx-click='edit-inbox']") |> render_click()

    html =
      lv
      |> element("button[phx-click='test-telegram']")
      |> render_click()

    assert html =~ "Connected as @acme_bot"

    assert %{"bot_username" => "acme_bot"} =
             account |> Inboxes.list_inboxes() |> hd() |> Map.get(:provider_config)
  end

  test "connects the telegram webhook", %{conn: conn, account: account} do
    bypass = Bypass.open()
    test_pid = self()

    Application.put_env(:chatwooter, :telegram_api_base, "http://localhost:#{bypass.port}")
    Application.put_env(:chatwooter, :webhook_base_url, "https://example.com")

    on_exit(fn ->
      Application.delete_env(:chatwooter, :telegram_api_base)
      Application.delete_env(:chatwooter, :webhook_base_url)
    end)

    {:ok, lv, _html} = live(conn, ~p"/app/settings/inboxes")

    lv
    |> form("#inbox-form", inbox: %{name: "TG", channel_type: "telegram"})
    |> render_submit()

    [%{id: inbox_id}] = Inboxes.list_inboxes(account)

    Bypass.expect_once(bypass, "POST", "/bottest-token/setWebhook", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:webhook_body, Jason.decode!(body)})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(
        200,
        Jason.encode!(%{"ok" => true, "result" => true, "description" => "Webhook was set"})
      )
    end)

    lv |> element("button[phx-click='edit-inbox']") |> render_click()

    lv
    |> form("#inbox-edit-form", inbox: %{name: "TG", provider_config: %{bot_token: "test-token"}})
    |> render_submit()

    lv |> element("button[phx-click='edit-inbox']") |> render_click()

    html =
      lv
      |> element("button[phx-click='connect-telegram']")
      |> render_click()

    assert html =~ "webhook connected"
    assert_received {:webhook_body, %{"url" => url, "secret_token" => secret}}
    assert url == "https://example.com/webhooks/telegram/#{inbox_id}"
    assert byte_size(secret) >= 32

    assert %{"webhook_secret" => ^secret, "webhook_url" => ^url} =
             account |> Inboxes.list_inboxes() |> hd() |> Map.get(:provider_config)
  end

  test "test without a saved token asks to save first", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app/settings/inboxes")

    lv
    |> form("#inbox-form", inbox: %{name: "TG", channel_type: "telegram"})
    |> render_submit()

    lv |> element("button[phx-click='edit-inbox']") |> render_click()

    # Sem stubs: qualquer HTTP derruba o teste.
    html =
      lv
      |> element("button[phx-click='test-telegram']")
      |> render_click()

    assert html =~ "Save a bot token first"
  end

  test "renames an inbox", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app/settings/inboxes")

    lv
    |> form("#inbox-form", inbox: %{name: "Suporte", channel_type: "telegram"})
    |> render_submit()

    html =
      lv
      |> element("button[phx-click='edit-inbox']")
      |> render_click()

    assert html =~ "Save"

    html =
      lv
      |> form("#inbox-edit-form", inbox: %{name: "Vendas", greeting_message: "Olá!"})
      |> render_submit()

    assert html =~ "Vendas"
    assert html =~ "Inbox updated"
  end

  test "creates and deletes an inbox", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app/settings/inboxes")

    html =
      lv
      |> form("#inbox-form", inbox: %{name: "Suporte", channel_type: "telegram"})
      |> render_submit()

    assert html =~ "Suporte"

    html =
      lv
      |> element("button[phx-click='delete-inbox']")
      |> render_click()

    refute html =~ "Suporte"
  end

  test "invites an agent and promotes them", %{conn: conn, account: account} do
    {:ok, lv, _html} = live(conn, ~p"/app/settings/agents")

    html =
      lv
      |> form("#invite-form", invite: %{name: "Agent", email: "agent@acme.inc", role: "agent"})
      |> render_submit()

    assert html =~ "Agent"
    assert html =~ "agent@acme.inc"

    member = Accounts.get_user_by_email("agent@acme.inc")
    assert member.name == "Agent"

    assert [%{role: :agent, availability: :offline}] =
             Accounts.list_account_users(account) |> Enum.filter(&(&1.user_id == member.id))

    html =
      lv
      |> element("#member-#{member.id} select[name='role']")
      |> render_change(%{"role" => "administrator", "id" => to_string(member.id)})

    assert html =~ "administrator"

    assert [%{role: :administrator}] =
             Accounts.list_account_users(account) |> Enum.filter(&(&1.user_id == member.id))
  end

  test "opens agent edit modal and renames", %{conn: conn, account: account} do
    {:ok, agent} = Accounts.create_agent(account, %{name: "Agent", email: "agent@acme.inc"})
    {:ok, lv, _html} = live(conn, ~p"/app/settings/agents")

    lv |> element("#member-#{agent.id} button[phx-click='edit-agent']") |> render_click()
    assert has_element?(lv, "#agent-form")
    assert render(lv) =~ "agent@acme.inc"

    lv
    |> form("#agent-form",
      agent: %{name: "Agent Renamed", role: "administrator", availability: "busy"}
    )
    |> render_submit()

    html = render(lv)
    assert html =~ "Agent Renamed"
    refute has_element?(lv, "#agent-form")

    updated = Accounts.get_user_by_email("agent@acme.inc")
    assert updated.name == "Agent Renamed"
  end

  test "agent edit modal shows validation errors", %{conn: conn, account: account} do
    {:ok, agent} = Accounts.create_agent(account, %{name: "Agent", email: "agent@acme.inc"})
    {:ok, lv, _html} = live(conn, ~p"/app/settings/agents")

    lv |> element("#member-#{agent.id} button[phx-click='edit-agent']") |> render_click()

    html =
      lv
      |> form("#agent-form", agent: %{name: "", role: "agent", availability: "online"})
      |> render_submit()

    assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
  end

  test "changes agent availability", %{conn: conn, account: account} do
    {:ok, agent} = Accounts.create_agent(account, %{name: "Agent", email: "agent@acme.inc"})
    {:ok, lv, _html} = live(conn, ~p"/app/settings/agents")

    html =
      lv
      |> element("#member-#{agent.id} select[name='availability']")
      |> render_change(%{"availability" => "busy", "id" => to_string(agent.id)})

    assert html =~ "Availability updated." or html =~ "busy"

    assert [%{availability: :busy}] =
             Accounts.list_account_users(account) |> Enum.filter(&(&1.user_id == agent.id))
  end
end
