defmodule Chatwooter.AttachmentsTest do
  @moduledoc "Anexos de mensagens (Fase 2: mídia do Telegram no RustFS)."
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes}
  alias Chatwooter.Conversations.Attachment

  setup do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "TG", channel_type: "telegram"})
    {:ok, contact} = Contacts.get_or_create_contact(account, %{name: "Maria"})
    {:ok, conv} = Conversations.open_conversation(account, inbox, contact, %{source_id: "555"})

    {:ok, message} =
      Conversations.add_message(conv, %{
        content: nil,
        content_type: "image",
        message_type: "incoming"
      })

    %{account: account, conv: conv, message: message}
  end

  defp attachment_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        file_type: "image",
        key: "telegram/1/2/f1.jpg",
        url: "http://localhost:9000/chatwooter-test/telegram/1/2/f1.jpg",
        content_type: "image/jpeg",
        size_bytes: 3
      },
      overrides
    )
  end

  test "create_attachment/2 links a stored file to the message", %{message: message} do
    Phoenix.PubSub.subscribe(Chatwooter.PubSub, "conversation:#{message.conversation_id}")

    assert {:ok, %Attachment{key: "telegram/1/2/f1.jpg", url: url}} =
             Conversations.create_attachment(message, attachment_attrs())

    assert url =~ "f1.jpg"
    assert_received {:message_updated, _}
    assert [%Attachment{}] = Conversations.list_attachments(message)
  end

  test "create_attachment/2 rejects missing key/url", %{message: message} do
    assert {:error, %Ecto.Changeset{}} =
             Conversations.create_attachment(message, %{file_type: "image"})
  end

  test "duplicate storage keys roll back the attachment row", %{message: message} do
    assert {:ok, original} = Conversations.create_attachment(message, attachment_attrs())

    assert {:error, %Ecto.Changeset{}} =
             Conversations.create_attachment(message, attachment_attrs())

    assert [%Attachment{id: id}] = Conversations.list_attachments(message)
    assert id == original.id

    assert {:ok, %Attachment{id: ^id}} =
             Conversations.fetch_attachment(message.id, "telegram/1/2/f1.jpg")
  end

  test "media type survives message reload without changing the upstream enum", %{
    message: message
  } do
    assert %{content_type: :image, upstream_content_type: :text} =
             Conversations.get_message!(message.id)

    assert [[0]] =
             Repo.query!("SELECT content_type FROM messages WHERE id = $1", [message.id]).rows
  end

  test "attachments are preloaded with the conversation", %{
    account: account,
    conv: conv,
    message: message
  } do
    {:ok, _} = Conversations.create_attachment(message, attachment_attrs())

    conversation = Conversations.get_conversation!(account, conv.id)
    assert [%Attachment{key: "telegram/1/2/f1.jpg"}] = hd(conversation.messages).attachments
  end
end
