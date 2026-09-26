defmodule Chatwooter.MessagingTest do
  @moduledoc "Fase 1: inboxes, contatos e conversas (domínio do dashboard)."
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes}
  alias Chatwooter.Contacts.Contact
  alias Chatwooter.Conversations.{Conversation, Message}
  alias Chatwooter.Inboxes.Inbox

  setup do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)
    %{account: account, owner: owner}
  end

  test "create_inbox/2 creates a whatsapp inbox", %{account: account} do
    assert {:ok, %Inbox{channel_type: :whatsapp}} =
             Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    assert [%Inbox{name: "Vendas"}] = Inboxes.list_inboxes(account)
  end

  test "create_inbox/2 rejects unknown channel", %{account: account} do
    assert {:error, %Ecto.Changeset{}} =
             Inboxes.create_inbox(account, %{name: "X", channel_type: "sms"})
  end

  test "contacts are deduplicated by phone number", %{account: account} do
    assert {:ok, %Contact{id: id}} =
             Contacts.get_or_create_contact(account, %{
               name: "Maria",
               phone_number: "+5511987654321"
             })

    assert {:ok, %Contact{id: ^id}} =
             Contacts.get_or_create_contact(account, %{
               name: "Maria Silva",
               phone_number: "+5511987654321"
             })
  end

  test "open_conversation/4 creates contact_inbox + open conversation", %{account: account} do
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    {:ok, contact} =
      Contacts.get_or_create_contact(account, %{name: "Maria", phone_number: "+5511987654321"})

    assert {:ok, %Conversation{status: :open} = conv} =
             Conversations.open_conversation(account, inbox, contact, %{
               source_id: "5511987654321"
             })

    assert [%Conversation{id: conv_id}] = Conversations.list_conversations(account)
    assert conv_id == conv.id
  end

  test "add_message/2 persists and broadcasts to the conversation topic", %{account: account} do
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    {:ok, contact} =
      Contacts.get_or_create_contact(account, %{name: "Maria", phone_number: "+5511987654321"})

    {:ok, conv} =
      Conversations.open_conversation(account, inbox, contact, %{source_id: "5511987654321"})

    Phoenix.PubSub.subscribe(Chatwooter.PubSub, "conversation:#{conv.id}")

    assert {:ok, %Message{message_type: :incoming, content: "Olá"}} =
             Conversations.add_message(conv, %{content: "Olá", message_type: "incoming"})

    assert_received {:new_message, %Message{content: "Olá"}}
  end

  test "list_conversations/2 filters by status", %{account: account} do
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    {:ok, contact} =
      Contacts.get_or_create_contact(account, %{name: "Maria", phone_number: "+5511987654321"})

    {:ok, conv} =
      Conversations.open_conversation(account, inbox, contact, %{source_id: "5511987654321"})

    {:ok, _} = Conversations.set_status(conv, "resolved")

    assert [%Conversation{status: :resolved}] =
             Conversations.list_conversations(account, status: "resolved")

    assert [] = Conversations.list_conversations(account, status: "open")
  end

  test "delete_inbox/2 removes the inbox and its conversations", %{account: account} do
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    {:ok, contact} =
      Contacts.get_or_create_contact(account, %{name: "Maria", phone_number: "+5511987654321"})

    {:ok, _conv} =
      Conversations.open_conversation(account, inbox, contact, %{source_id: "5511987654321"})

    assert {:ok, _} = Inboxes.delete_inbox(account, inbox.id)
    assert [] = Inboxes.list_inboxes(account)
    assert [] = Conversations.list_conversations(account)
  end
end
