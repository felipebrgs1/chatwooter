defmodule ChatwooterWeb.ContactDetailsLiveTest do
  use ChatwooterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes, Repo}
  alias Chatwooter.Contacts.{Contact, CustomAttributeDefinition, Label}

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, user)

    {:ok, contact} =
      Contacts.get_or_create_contact(account, %{
        name: "Maria da Silva",
        phone_number: "+5511987654321",
        email: "maria@acme.com"
      })

    %{conn: log_in_user(conn, user), user: user, account: account, contact: contact}
  end

  test "shows breadcrumb, profile header and the edit form", %{conn: conn, contact: contact} do
    {:ok, lv, _html} = live(conn, ~p"/app/contacts/#{contact.id}")

    assert has_element?(lv, "#contact-breadcrumb", "Contacts")
    assert has_element?(lv, "#contact-breadcrumb", "Maria da Silva")
    assert has_element?(lv, "#contact-profile h3", "Maria da Silva")
    assert has_element?(lv, "#contact-profile", "Created")
    assert has_element?(lv, "#contact-form input[name='contact[first_name]'][value='Maria']")
    assert has_element?(lv, "#contact-form input[name='contact[last_name]'][value='da Silva']")

    assert has_element?(
             lv,
             "#contact-form input[name='contact[phone_local]'][value='11987654321']"
           )

    assert has_element?(lv, "#contact-phone-country", "+55")

    for tab <- ~w(attributes history notes media merge) do
      assert has_element?(lv, "#contact-tab-#{tab}")
    end

    assert has_element?(lv, "#contact-tab-attributes[aria-selected=true]")
  end

  test "updates the contact joining first and last name", %{conn: conn, contact: contact} do
    {:ok, lv, _html} = live(conn, ~p"/app/contacts/#{contact.id}")

    lv
    |> form("#contact-form",
      contact: %{
        first_name: "Maria",
        last_name: "Souza",
        city: "Recife",
        description: "Cliente VIP",
        social: %{linkedin: "maria-souza"}
      }
    )
    |> render_submit()

    updated = Repo.get!(Contact, contact.id)
    assert updated.name == "Maria Souza"
    assert updated.additional_attributes["city"] == "Recife"
    assert updated.additional_attributes["description"] == "Cliente VIP"
    assert updated.additional_attributes["social_profiles"]["linkedin"] == "maria-souza"
    assert has_element?(lv, "#contact-profile h3", "Maria Souza")
  end

  test "country and phone country come from the searchable lists", %{conn: conn, contact: contact} do
    {:ok, lv, _html} = live(conn, ~p"/app/contacts/#{contact.id}")

    lv |> element("#contact-country-option-PT") |> render_click()
    lv |> element("#contact-phone-country-menu-option-US") |> render_click()
    lv |> form("#contact-form") |> render_submit()

    updated = Repo.get!(Contact, contact.id)
    assert updated.additional_attributes["country_code"] == "PT"
    assert updated.additional_attributes["country"] == "Portugal"
    assert updated.phone_number == "+111987654321"
  end

  test "blocks and unblocks from the header", %{conn: conn, contact: contact} do
    {:ok, lv, _html} = live(conn, ~p"/app/contacts/#{contact.id}")

    lv |> element("#contact-block-toggle", "Block contact") |> render_click()
    assert Repo.get!(Contact, contact.id).blocked
    assert has_element?(lv, "#contact-block-toggle", "Unblock contact")
  end

  test "adds and removes labels", %{conn: conn, account: account, contact: contact} do
    Repo.insert!(%Label{account_id: account.id, title: "vip", color: "#ff0000"})
    {:ok, lv, _html} = live(conn, ~p"/app/contacts/#{contact.id}")

    lv |> element("#contact-labels-menu-option-vip") |> render_click()
    assert has_element?(lv, "#contact-label-vip")
    assert Contacts.list_contact_labels(contact) == ["vip"]

    lv |> element("#contact-label-vip button") |> render_click()
    refute has_element?(lv, "#contact-label-vip")
  end

  test "deletes the contact after confirming", %{conn: conn, contact: contact} do
    {:ok, lv, _html} = live(conn, ~p"/app/contacts/#{contact.id}")

    assert {:error, {:live_redirect, %{to: "/app/contacts"}}} =
             lv |> form("#delete-contact-dialog form") |> render_submit()

    refute Repo.get(Contact, contact.id)
  end

  describe "sidebar tabs" do
    test "attributes: sets a value for an unused attribute", %{
      conn: conn,
      account: account,
      contact: contact
    } do
      Repo.insert!(%CustomAttributeDefinition{
        account_id: account.id,
        attribute_key: "tier",
        attribute_display_name: "Tier",
        attribute_model: :contact_attribute
      })

      {:ok, lv, _html} = live(conn, ~p"/app/contacts/#{contact.id}")
      assert has_element?(lv, "#contact-attributes", "1 Unused attribute")

      lv
      |> form("#attribute-form-tier", attribute: %{value: "gold"})
      |> render_submit()

      assert Repo.get!(Contact, contact.id).custom_attributes["tier"] == "gold"
      assert has_element?(lv, "#contact-attribute-tier[data-used]")
    end

    test "history lists previous conversations", %{conn: conn, account: account, contact: contact} do
      {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})
      {:ok, conv} = Conversations.open_conversation(account, inbox, contact, %{source_id: "1"})

      {:ok, lv, _html} = live(conn, ~p"/app/contacts/#{contact.id}")
      lv |> element("#contact-tab-history") |> render_click()

      assert has_element?(lv, "#contact-history-#{conv.id}", "Maria da Silva")
    end

    test "notes: adds and deletes", %{conn: conn, contact: contact} do
      {:ok, lv, _html} = live(conn, ~p"/app/contacts/#{contact.id}")
      lv |> element("#contact-tab-notes") |> render_click()

      lv |> form("#contact-note-form", note: %{content: "Ligar amanhã"}) |> render_submit()
      assert has_element?(lv, "#contact-notes", "Ligar amanhã")

      [note] = Contacts.list_contact_notes(Repo.preload(contact, :account).account, contact)
      lv |> element("#contact-note-#{note.id} button") |> render_click()
      refute has_element?(lv, "#contact-notes", "Ligar amanhã")
    end

    test "media: empty state", %{conn: conn, contact: contact} do
      {:ok, lv, _html} = live(conn, ~p"/app/contacts/#{contact.id}")
      lv |> element("#contact-tab-media") |> render_click()
      assert has_element?(lv, "#contact-media", "No attachments yet")
    end

    test "merge: merges into the chosen primary contact", %{
      conn: conn,
      account: account,
      contact: contact
    } do
      {:ok, primary} =
        Contacts.get_or_create_contact(account, %{
          name: "Maria Oficial",
          phone_number: "+5511900000000"
        })

      {:ok, lv, _html} = live(conn, ~p"/app/contacts/#{contact.id}")
      lv |> element("#contact-tab-merge") |> render_click()

      lv |> element("#merge-primary-option-#{primary.id}") |> render_click()

      assert {:error, {:live_redirect, %{to: path}}} =
               lv |> element("#merge-confirm") |> render_click()

      assert path == "/app/contacts/#{primary.id}"
      refute Repo.get(Contact, contact.id)
    end
  end
end
