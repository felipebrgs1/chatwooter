defmodule Chatwooter.ConversationsSendTest do
  @moduledoc "Envio de respostas do agente (persiste outgoing; entrega via worker)."
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes}
  alias Chatwooter.Conversations.Message

  setup do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "TG", channel_type: "telegram"})

    {:ok, contact} =
      Contacts.get_or_create_contact(account, %{name: "Maria"})

    {:ok, conv} =
      Conversations.open_conversation(account, inbox, contact, %{source_id: "555"})

    %{account: account, owner: owner, conv: conv}
  end

  test "send_message persists an outgoing message as sent", %{
    account: account,
    owner: owner,
    conv: conv
  } do
    Phoenix.PubSub.subscribe(Chatwooter.PubSub, "account:#{account.id}")

    assert {:ok, %Message{message_type: :outgoing, status: :sent, content: "Oi"}} =
             Conversations.send_message(conv, %{content: "Oi", sender_id: owner.id})

    assert_received {:new_message, %Message{content: "Oi"}}
  end
end
