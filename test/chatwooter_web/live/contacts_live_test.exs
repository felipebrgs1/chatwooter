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
      contact: %{name: "João", phone_number: "+5511922222222", company: "Other"}
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

  test "detail page shows attributes and conversation history", %{
    conn: conn,
    account: account
  } do
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    {:ok, contact} =
      Contacts.get_or_create_contact(account, %{name: "Maria", phone_number: "+5511987654321"})

    {:ok, conv} =
      Conversations.open_conversation(account, inbox, contact, %{source_id: "5511987654321"})

    {:ok, lv, _html} = live(conn, ~p"/app/contacts/#{contact.id}")

    html = render(lv)
    assert html =~ "Maria"
    assert html =~ "+5511987654321"
    assert has_element?(lv, "#history-#{conv.id}")
    assert html =~ "via Vendas"
  end
end
