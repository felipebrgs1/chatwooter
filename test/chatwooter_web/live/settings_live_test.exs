defmodule ChatwooterWeb.SettingsLiveTest do
  use ChatwooterWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures

  alias Chatwooter.Accounts

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
      |> form("#invite-form", invite: %{email: "agent@acme.inc"})
      |> render_submit()

    assert html =~ "agent@acme.inc"

    member = Accounts.get_user_by_email("agent@acme.inc")

    html =
      lv
      |> element("#member-#{member.id} select")
      |> render_change(%{"role" => "admin", "id" => to_string(member.id)})

    assert html =~ "admin"

    assert [%{role: :admin}] =
             Accounts.list_account_users(account) |> Enum.filter(&(&1.user_id == member.id))
  end
end
