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

  test "detail page updates profile directly and synchronizes company name", %{
    conn: conn,
    account: account
  } do
    {:ok, company} = Companies.create_company(account, %{name: "Acme"})
    {:ok, contact} = Contacts.create_contact(account, %{name: "Maria"})
    {:ok, _} = Contacts.assign_company(contact, company)

    {:ok, lv, _html} = live(conn, ~p"/app/companies/#{company.id}")

    assert render(lv) =~ "Maria"
    assert render(lv) =~ ">1<"
    assert render(lv) =~ "Created"

    lv
    |> form("#company-profile-form",
      company: %{
        name: "Acme Corporation",
        domain: "acme.corp",
        description: "Global delivery services"
      }
    )
    |> render_submit()

    html = render(lv)
    assert html =~ "Acme Corporation"
    assert html =~ "acme.corp"

    assert Contacts.get_contact!(account, contact.id).additional_attributes["company_name"] ==
             "Acme Corporation"
  end

  test "detail page manages custom attributes", %{conn: conn, account: account} do
    {:ok, company} = Companies.create_company(account, %{name: "Acme"})
    {:ok, lv, _html} = live(conn, ~p"/app/companies/#{company.id}")

    assert render(lv) =~ "No custom attributes yet."

    lv
    |> form("#custom-form", custom: %{key: "industry", value: "tech"})
    |> render_submit()

    html = render(lv)
    assert html =~ "industry"
    assert html =~ "tech"

    lv
    |> element("#custom-industry button")
    |> render_click()

    assert render(lv) =~ "No custom attributes yet."
  end

  test "filters companies by contact status and toggles drawer", %{conn: conn, account: account} do
    {:ok, c1} = Companies.create_company(account, %{name: "Alpha Corp"})
    {:ok, _c2} = Companies.create_company(account, %{name: "Empty Corp"})
    {:ok, contact} = Contacts.create_contact(account, %{name: "Pedro"})
    {:ok, _} = Contacts.assign_company(contact, c1)

    {:ok, lv, _html} = live(conn, ~p"/app/companies")

    # Toggle filter drawer
    lv |> element("#toggle-company-filter") |> render_click()
    assert has_element?(lv, "#company-filter-drawer")

    # Filter by has contacts
    html = lv |> render_hook("apply-filters", %{"has_contacts" => "with_contacts"})
    assert html =~ "Alpha Corp"
    refute html =~ "Empty Corp"

    # Filter by no contacts
    html = lv |> render_hook("apply-filters", %{"has_contacts" => "no_contacts"})
    assert html =~ "Empty Corp"
    refute html =~ "Alpha Corp"

    # Clear filters
    html = lv |> render_hook("clear-filters", %{})
    assert html =~ "Alpha Corp"
    assert html =~ "Empty Corp"
  end
end
