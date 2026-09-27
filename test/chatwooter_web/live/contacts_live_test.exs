defmodule ChatwooterWeb.ContactsLiveTest do
  use ChatwooterWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes}

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, user)
    %{conn: log_in_user(conn, user), account: account}
  end

  test "redirects guests to login" do
    assert {:error, {:redirect, %{to: "/app/login"}}} = live(build_conn(), ~p"/app/contacts")
  end

  test "lists contacts as cards and creates one via modal", %{conn: conn, account: account} do
    {:ok, other_co} = Chatwooter.Companies.create_company(account, %{name: "Other"})

    {:ok, _} =
      Contacts.create_contact(account, %{
        name: "Maria",
        phone_number: "+5511911111111",
        additional_attributes: %{
          "company_name" => "Acme",
          "city" => "São Paulo",
          "country" => "Brazil"
        }
      })

    {:ok, lv, _html} = live(conn, ~p"/app/contacts")
    assert has_element?(lv, "#contact-search")
    assert render(lv) =~ "Maria"
    assert render(lv) =~ "Acme"
    assert render(lv) =~ "São Paulo, Brazil"
    assert render(lv) =~ "View details"

    lv |> element("#new-contact") |> render_click()
    assert has_element?(lv, "#contact-form")

    lv
    |> form("#contact-form",
      contact: %{name: "João", phone_number: "+5511922222222", company_id: other_co.id}
    )
    |> render_submit()

    html = render(lv)
    assert html =~ "João"
    assert html =~ "Other"
    refute has_element?(lv, "#contact-modal")
  end

  test "expands a card and quick-edits inline", %{conn: conn, account: account} do
    {:ok, contact} =
      Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511911111111"})

    {:ok, lv, _html} = live(conn, ~p"/app/contacts")

    lv |> element("#contact-#{contact.id} button[aria-label='Expand']") |> render_click()
    assert has_element?(lv, "#quick-form-#{contact.id}")

    lv
    |> form("#quick-form-#{contact.id}", contact: %{name: "Maria Silva", city: "Rio"})
    |> render_submit()

    html = render(lv)
    assert html =~ "Maria Silva"
    assert html =~ "Rio"
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

  test "filters contacts by company and blocked status", %{conn: conn, account: account} do
    {:ok, company} = Chatwooter.Companies.create_company(account, %{name: "Beta Corp"})

    {:ok, _c1} =
      Contacts.create_contact(account, %{
        name: "Carlos Ativo",
        phone_number: "+5511933333333",
        company_id: company.id,
        blocked: false
      })

    {:ok, _c2} =
      Contacts.create_contact(account, %{
        name: "Carla Bloqueada",
        phone_number: "+5511944444444",
        blocked: true
      })

    {:ok, lv, _html} = live(conn, ~p"/app/contacts")

    # Toggle filter drawer
    lv |> element("#toggle-filter") |> render_click()
    assert has_element?(lv, "#filter-drawer")

    # Filter by company
    html =
      lv |> render_hook("apply-filters", %{"company" => to_string(company.id), "blocked" => ""})

    assert html =~ "Carlos Ativo"
    refute html =~ "Carla Bloqueada"

    # Filter by blocked status
    html = lv |> render_hook("apply-filters", %{"company" => "", "blocked" => "true"})
    assert html =~ "Carla Bloqueada"
    refute html =~ "Carlos Ativo"

    # Clear filters
    html = lv |> render_hook("clear-filters", %{})
    assert html =~ "Carlos Ativo"
    assert html =~ "Carla Bloqueada"
  end

  test "detail page shows attributes and conversation history", %{
    conn: conn,
    account: account
  } do
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    {:ok, contact} =
      Contacts.get_or_create_contact(account, %{
        name: "Maria",
        phone_number: "+5511987654321",
        custom_attributes: %{"tier" => "gold"}
      })

    {:ok, conv} =
      Conversations.open_conversation(account, inbox, contact, %{source_id: "5511987654321"})

    {:ok, lv, _html} = live(conn, ~p"/app/contacts/#{contact.id}")

    html = render(lv)
    assert html =~ "Maria"
    assert html =~ "+5511987654321"
    assert has_element?(lv, "#contact-detail-sidebar")
    assert has_element?(lv, "#contact-conversations")
    assert has_element?(lv, "#contact-profile")
    assert has_element?(lv, "#contact-information")
    assert has_element?(lv, "#history-#{conv.id}")
    assert html =~ "via Vendas"

    lv |> element("aside#contact-detail-sidebar button", "Channels") |> render_click()
    assert has_element?(lv, "#contact-inboxes")

    assert has_element?(lv, "#quick-form-#{contact.id}")

    lv
    |> form("#quick-form-#{contact.id}",
      contact: %{
        name: "Maria da Silva",
        identifier: "maria-123",
        location: "São Paulo",
        country_code: "BR",
        city: "São Paulo",
        country: "Brazil",
        description: "Cliente desde 2024",
        social_linkedin: "https://linkedin.com/in/maria",
        custom_attributes_json: ~s({"tier":"platinum","source":"referral"})
      }
    )
    |> render_submit()

    updated = Contacts.get_contact!(account, contact.id)
    assert updated.name == "Maria da Silva"
    assert updated.identifier == "maria-123"
    assert updated.location == "São Paulo"
    assert updated.country_code == "BR"
    assert updated.additional_attributes["description"] == "Cliente desde 2024"

    assert updated.additional_attributes["social_profiles"]["linkedin"] ==
             "https://linkedin.com/in/maria"

    assert updated.custom_attributes == %{"tier" => "platinum", "source" => "referral"}
  end
end
