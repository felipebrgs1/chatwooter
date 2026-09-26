defmodule ChatwooterWeb.ContactsLiveTest do
  use ChatwooterWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures

  alias Chatwooter.{Accounts, Contacts}

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, user)
    %{conn: log_in_user(conn, user), account: account}
  end

  test "redirects guests to login" do
    assert {:error, {:redirect, %{to: "/app/login"}}} = live(build_conn(), ~p"/app/contacts")
  end

  test "lists contacts and creates one via modal", %{conn: conn, account: account} do
    {:ok, _} = Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511911111111"})

    {:ok, lv, _html} = live(conn, ~p"/app/contacts")
    assert has_element?(lv, "#contact-search")
    assert render(lv) =~ "Maria"

    lv |> element("#new-contact") |> render_click()
    assert has_element?(lv, "#contact-form")

    lv
    |> form("#contact-form", contact: %{name: "João", phone_number: "+5511922222222"})
    |> render_submit()

    assert render(lv) =~ "João"
    refute has_element?(lv, "#contact-modal")
  end

  test "shows validation errors for blank name", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app/contacts")

    lv |> element("#new-contact") |> render_click()

    html =
      lv
      |> form("#contact-form", contact: %{name: "", phone_number: "+5511911111111"})
      |> render_submit()

    assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
  end

  test "search filters the list", %{conn: conn, account: account} do
    {:ok, _} = Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511911111111"})
    {:ok, _} = Contacts.create_contact(account, %{name: "João", phone_number: "+5511922222222"})

    {:ok, lv, _html} = live(conn, ~p"/app/contacts")

    html =
      lv
      |> form("#contact-search", %{q: "maria"})
      |> render_change()

    assert html =~ "Maria"
    refute html =~ "João"
  end
end
