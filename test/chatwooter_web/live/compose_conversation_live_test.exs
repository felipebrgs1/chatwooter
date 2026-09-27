defmodule ChatwooterWeb.ComposeConversationLiveTest do
  @moduledoc "Popover de nova conversa (`NewConversation/ComposeConversation.vue`)."
  use ChatwooterWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes}

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, user)
    %{conn: log_in_user(conn, user), user: user, account: account}
  end

  defp telegram_inbox(account) do
    {:ok, inbox} =
      Inboxes.create_inbox(account, %{
        name: "TG",
        channel_type: "telegram",
        provider_config: %{"bot_token" => "tg-token"}
      })

    inbox
  end

  defp stub_telegram(message_id) do
    bypass = Bypass.open()
    Application.put_env(:chatwooter, :telegram_api_base, "http://localhost:#{bypass.port}")
    on_exit(fn -> Application.delete_env(:chatwooter, :telegram_api_base) end)

    Bypass.expect_once(bypass, "POST", "/bottg-token/sendMessage", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(
        200,
        Jason.encode!(%{"ok" => true, "result" => %{"message_id" => message_id}})
      )
    end)
  end

  defp open_compose(lv) do
    lv |> element("#sidebar-compose") |> render_click()
    lv
  end

  defp search(lv, query) do
    lv |> form("#compose-contact-search", %{q: query}) |> render_change()
    lv
  end

  test "the sidebar compose button toggles the popover", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app")
    refute has_element?(lv, "#compose-conversation")

    open_compose(lv)
    assert has_element?(lv, "#compose-conversation", "To:")
    assert has_element?(lv, "#compose-conversation", "Via:")
    assert has_element?(lv, "#compose-show-inboxes[disabled]", "Show inboxes")

    lv |> element("#sidebar-compose") |> render_click()
    refute has_element?(lv, "#compose-conversation")
  end

  test "searches a contact, picks an inbox and starts the conversation", %{
    conn: conn,
    account: account
  } do
    stub_telegram(31)
    inbox = telegram_inbox(account)
    {:ok, maria} = Contacts.create_contact(account, %{name: "Maria", email: "maria@acme.com"})
    {:ok, _} = Contacts.get_or_create_contact_inbox(maria, inbox, "4242")

    {:ok, lv, _html} = live(conn, ~p"/app/contacts")
    lv |> open_compose() |> search("m")
    refute has_element?(lv, "#compose-contact-option-#{maria.id}")

    search(lv, "mar")
    assert has_element?(lv, "#compose-contact-option-#{maria.id}", "Maria (maria@acme.com)")

    lv |> element("#compose-contact-option-#{maria.id}") |> render_click()
    assert has_element?(lv, "#compose-selected-contact", "Maria (maria@acme.com)")
    assert has_element?(lv, "#compose-inbox-option-#{inbox.id}", "TG")

    lv |> element("#compose-inbox-option-#{inbox.id}") |> render_click()
    assert has_element?(lv, "#compose-target-inbox", "TG")
    assert has_element?(lv, "#compose-send", "Send")

    lv |> form("#compose-message-form", %{message: "Olá Maria"}) |> render_submit()

    assert [conversation] = Conversations.list_contact_conversations(account, maria)
    assert_redirect(lv, ~p"/app?conversation_id=#{conversation.id}")

    assert [%{content: "Olá Maria", source_id: "31"}] =
             Conversations.get_conversation!(account, conversation.id).messages
  end

  test "only lists contacts with an email or phone number", %{conn: conn, account: account} do
    {:ok, maria} =
      Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511900000001"})

    {:ok, mariana} = Contacts.create_contact(account, %{name: "Mariana"})

    {:ok, lv, _html} = live(conn, ~p"/app")
    lv |> open_compose() |> search("mari")

    assert has_element?(lv, "#compose-contact-option-#{maria.id}", "Maria")
    refute has_element?(lv, "#compose-contact-option-#{mariana.id}")
  end

  test "does not send without a message", %{conn: conn, account: account} do
    inbox = telegram_inbox(account)
    {:ok, maria} = Contacts.create_contact(account, %{name: "Maria", email: "maria@acme.com"})
    {:ok, _} = Contacts.get_or_create_contact_inbox(maria, inbox, "4242")

    {:ok, lv, _html} = live(conn, ~p"/app")
    lv |> open_compose() |> search("maria")
    lv |> element("#compose-contact-option-#{maria.id}") |> render_click()
    lv |> element("#compose-inbox-option-#{inbox.id}") |> render_click()
    lv |> form("#compose-message-form", %{message: " "}) |> render_submit()

    assert has_element?(lv, "#compose-message-form textarea[aria-invalid=true]")
    assert Conversations.list_contact_conversations(account, maria) == []
  end

  test "creates the contact from the typed email when nobody matches", %{
    conn: conn,
    account: account
  } do
    {:ok, lv, _html} = live(conn, ~p"/app")
    lv |> open_compose() |> search("novo@acme.com")

    assert has_element?(lv, "#compose-contact-create", "novo@acme.com")
    lv |> element("#compose-contact-create") |> render_click()

    assert [contact] = Contacts.list_contacts(account)
    assert contact.name == "Novo"
    assert contact.email == "novo@acme.com"
    assert has_element?(lv, "#compose-selected-contact", "Novo (novo@acme.com)")

    assert has_element?(
             lv,
             "#compose-no-inbox",
             "There are no available inboxes to start a conversation with this contact."
           )
  end

  test "whatsapp inboxes need a template instead of free text", %{conn: conn, account: account} do
    {:ok, wa} = Inboxes.create_inbox(account, %{name: "WA", channel_type: "whatsapp"})

    {:ok, maria} =
      Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511900000001"})

    {:ok, lv, _html} = live(conn, ~p"/app")
    lv |> open_compose() |> search("maria")
    lv |> element("#compose-contact-option-#{maria.id}") |> render_click()
    lv |> element("#compose-inbox-option-#{wa.id}") |> render_click()

    assert has_element?(lv, "#compose-whatsapp-templates", "Select template")
    refute has_element?(lv, "#compose-message-form")
    refute has_element?(lv, "#compose-send")
  end

  test "discard clears the form and closes the popover", %{conn: conn, account: account} do
    {:ok, maria} = Contacts.create_contact(account, %{name: "Maria", email: "maria@acme.com"})

    {:ok, lv, _html} = live(conn, ~p"/app")
    lv |> open_compose() |> search("maria")
    lv |> element("#compose-contact-option-#{maria.id}") |> render_click()
    lv |> element("#compose-discard") |> render_click()
    refute has_element?(lv, "#compose-conversation")

    open_compose(lv)
    refute has_element?(lv, "#compose-selected-contact")
  end

  test "send message on the contact page preselects the contact", %{
    conn: conn,
    account: account
  } do
    inbox = telegram_inbox(account)
    {:ok, maria} = Contacts.create_contact(account, %{name: "Maria", email: "maria@acme.com"})
    {:ok, _} = Contacts.get_or_create_contact_inbox(maria, inbox, "4242")

    {:ok, lv, _html} = live(conn, ~p"/app/contacts/#{maria.id}")
    lv |> element("#contact-send-message") |> render_click()

    assert has_element?(lv, "#compose-selected-contact", "Maria (maria@acme.com)")
    refute has_element?(lv, "#compose-clear-contact")
    assert has_element?(lv, "#compose-show-inboxes")

    lv |> element("#compose-show-inboxes") |> render_click()
    assert has_element?(lv, "#compose-inbox-option-#{inbox.id}")
  end
end
