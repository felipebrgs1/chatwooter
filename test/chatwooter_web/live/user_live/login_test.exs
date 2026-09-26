defmodule ChatwooterWeb.UserLive.LoginTest do
  use ChatwooterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app/login")

      assert html =~ "Log in"
      assert html =~ "Sign up"
      assert html =~ "Password"
    end
  end

  describe "user login - password" do
    test "redirects if user logs in with valid credentials", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/app/login")

      form =
        form(lv, "#login_form_password",
          user: %{email: user.email, password: valid_user_password(), remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to login page with a flash error if credentials are invalid", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/login")

      form =
        form(lv, "#login_form_password", user: %{email: "test@email.com", password: "123456"})

      render_submit(form, %{user: %{remember_me: true}})

      conn = follow_trigger_action(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/app/login"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app/login")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Sign up")
        |> render_click()
        |> follow_redirect(conn, ~p"/app/signup")

      assert login_html =~ "Register"
    end
  end

  describe "already logged in" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "redirects to the dashboard", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/app"}}} = live(conn, ~p"/app/login")
    end

    test "stays for sudo re-authentication", %{conn: conn, user: user} do
      conn =
        conn
        |> fetch_session()
        |> Phoenix.Controller.fetch_flash([])
        |> Phoenix.Controller.put_flash(:error, "You must re-authenticate to access this page.")

      {:ok, _lv, html} = live(conn, ~p"/app/login")

      assert html =~ "You need to reauthenticate"

      assert html =~
               ~s(<input type="email" name="user[email]" id="login_form_password_email" value="#{user.email}")
    end
  end
end
