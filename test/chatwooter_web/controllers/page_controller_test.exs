defmodule ChatwooterWeb.PageControllerTest do
  use ChatwooterWeb.ConnCase

  test "GET / redirects guests to login", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/users/log-in"
  end

  test "GET / redirects users to the dashboard", %{conn: conn} do
    user = Chatwooter.AccountsFixtures.user_fixture()
    conn = ChatwooterWeb.ConnCase.log_in_user(conn, user)
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/app"
  end
end
