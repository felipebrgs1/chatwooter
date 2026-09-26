defmodule ChatwooterWeb.CompaniesLiveTest do
  use ChatwooterWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures

  alias Chatwooter.{Accounts, Companies, Contacts}

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, user)
    %{conn: log_in_user(conn, user), account: account}
  end

  test "redirects guests to login" do
    assert {:error, {:redirect, %{to: "/app/login"}}} = live(build_conn(), ~p"/app/companies")
  end

  test "lists companies and creates one via modal", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app/companies")
    assert has_element?(lv, "#company-search")

    lv |> element("#new-company") |> render_click()
    assert has_element?(lv, "#company-form")

    lv
    |> form("#company-form", company: %{name: "Acme Inc", domain: "acme.inc"})
    |> render_submit()

    html = render(lv)
    assert html =~ "Acme Inc"
    assert html =~ "acme.inc"
    refute has_element?(lv, "#company-modal")
  end

  test "shows validation errors for blank name", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app/companies")

    lv |> element("#new-company") |> render_click()

    html =
      lv
      |> form("#company-form", company: %{name: "", domain: "nope"})
      |> render_submit()

    assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
  end

  test "search filters the list", %{conn: conn, account: account} do
    {:ok, _} = Companies.create_company(account, %{name: "Acme"})
    {:ok, _} = Companies.create_company(account, %{name: "Other Co"})

    {:ok, lv, _html} = live(conn, ~p"/app/companies")

    html =
      lv
      |> form("#company-search", %{q: "acme"})
      |> render_change()

    assert html =~ "Acme"
    refute html =~ "Other Co"
  end

  test "detail page shows contacts and renames with sync", %{conn: conn, account: account} do
    {:ok, company} = Companies.create_company(account, %{name: "Acme"})
    {:ok, contact} = Contacts.create_contact(account, %{name: "Maria"})
    {:ok, _} = Contacts.assign_company(contact, company)

    {:ok, lv, _html} = live(conn, ~p"/app/companies/#{company.id}")

    assert render(lv) =~ "Maria"
    assert render(lv) =~ ">1<"

    lv |> element("#company-detail button[phx-click='edit']") |> render_click()

    lv
    |> form("#company-form", company: %{name: "Acme Inc"})
    |> render_submit()

    assert render(lv) =~ "Acme Inc"

    assert Contacts.get_contact!(account, contact.id).additional_attributes["company_name"] ==
             "Acme Inc"
  end
end
