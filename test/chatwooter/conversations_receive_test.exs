defmodule Chatwooter.ConversationsReceiveTest do
  @moduledoc "Ingest de mensagens de canal: contato + conversa + mensagem idempotente."
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Conversations, Inboxes}
  alias Chatwooter.Conversations.{Conversation, Message}

  setup do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)

    {:ok, inbox} =
      Inboxes.create_inbox(account, %{name: "TG", channel_type: "telegram"})

    %{account: account, inbox: inbox}
  end

  defp normalized(overrides \\ %{}) do
    Map.merge(
      %{
        channel: :telegram,
        source_id: "555",
        sender_name: "Maria",
        type: :text,
        content: "Olá",
        file_id: nil,
        external_id: "42",
        timestamp: 1_727_280_000
      },
      overrides
    )
  end

  test "creates contact, conversation and incoming message", %{
    account: account,
    inbox: inbox
  } do
    Phoenix.PubSub.subscribe(Chatwooter.PubSub, "account:#{account.id}")

    assert {:ok,
            %{
              conversation: %Conversation{id: cid},
              message: %Message{
                content: "Olá",
                message_type: :incoming,
                content_type: :text,
                source_id: "42"
              },
              duplicate?: false
            }} = Conversations.receive_message(account, inbox, normalized())

    assert_received {:new_message, %Message{content: "Olá"}}

    conversation = Conversations.get_conversation!(account, cid)
    assert conversation.contact_inbox.contact.name == "Maria"
    assert conversation.contact_inbox.source_id == "555"
  end

  test "is idempotent by external id", %{account: account, inbox: inbox} do
    assert {:ok, %{message: %{id: first_id}}} =
             Conversations.receive_message(account, inbox, normalized())

    assert {:ok, %{message: %{id: second_id}, duplicate?: true}} =
             Conversations.receive_message(account, inbox, normalized())

    assert first_id == second_id
    assert Chatwooter.Repo.aggregate(Message, :count) == 1
  end

  test "reuses the open conversation", %{account: account, inbox: inbox} do
    assert {:ok, %{conversation: %{id: first_cid}}} =
             Conversations.receive_message(account, inbox, normalized())

    assert {:ok, %{conversation: %{id: second_cid}, duplicate?: false}} =
             Conversations.receive_message(account, inbox, normalized(%{external_id: "43"}))

    assert first_cid == second_cid
    assert Chatwooter.Repo.aggregate(Conversation, :count) == 1
    assert Chatwooter.Repo.aggregate(Message, :count) == 2
  end

  test "reopens a resolved conversation", %{account: account, inbox: inbox} do
    assert {:ok, %{conversation: conversation}} =
             Conversations.receive_message(account, inbox, normalized())

    {:ok, _} = Conversations.set_status(conversation, "resolved")

    assert {:ok, %{conversation: %{id: cid, status: :open}}} =
             Conversations.receive_message(account, inbox, normalized(%{external_id: "44"}))

    assert cid == conversation.id
    assert Chatwooter.Repo.aggregate(Conversation, :count) == 1
  end

  test "falls back to a generic contact name", %{account: account, inbox: inbox} do
    assert {:ok, %{conversation: %{id: cid}}} =
             Conversations.receive_message(account, inbox, normalized(%{sender_name: nil}))

    conversation = Conversations.get_conversation!(account, cid)
    assert conversation.contact_inbox.contact.name == "Contact 555"
  end

  test "stores images without caption", %{account: account, inbox: inbox} do
    assert {:ok, %{message: %Message{content_type: :image, content: nil}}} =
             Conversations.receive_message(
               account,
               inbox,
               normalized(%{type: :image, content: nil, external_id: "45"})
             )
  end
end
