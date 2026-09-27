defmodule Chatwooter.ComposeConversationTest do
  @moduledoc """
  Nova conversa iniciada pelo agente (`NewConversation/ComposeConversation.vue`):
  inboxes "contactáveis" e criação da conversa com a 1ª mensagem.
  """
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes}
  alias Chatwooter.Conversations.Message
  alias Chatwooter.Platform.ComposeConversation

  setup do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)
    %{owner: owner, account: account}
  end

  describe "Contacts.list_contactable_inboxes/2" do
    test "whatsapp needs a phone number (source id without +)", %{account: account} do
      {:ok, wa} = Inboxes.create_inbox(account, %{name: "WA", channel_type: "whatsapp"})

      {:ok, with_phone} =
        Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511900000001"})

      {:ok, email_only} = Contacts.create_contact(account, %{name: "Ana", email: "ana@acme.com"})

      assert [%{inbox: %{id: inbox_id}, source_id: "5511900000001"}] =
               Contacts.list_contactable_inboxes(account, with_phone)

      assert inbox_id == wa.id
      assert Contacts.list_contactable_inboxes(account, email_only) == []
    end

    test "telegram only when the contact already talked to the bot", %{account: account} do
      {:ok, tg} = Inboxes.create_inbox(account, %{name: "TG", channel_type: "telegram"})
      {:ok, known} = Contacts.create_contact(account, %{name: "Maria", email: "maria@acme.com"})
      {:ok, _} = Contacts.get_or_create_contact_inbox(known, tg, "4242")
      {:ok, stranger} = Contacts.create_contact(account, %{name: "Ana", email: "ana@acme.com"})

      assert [%{inbox: %{id: inbox_id}, source_id: "4242"}] =
               Contacts.list_contactable_inboxes(account, known)

      assert inbox_id == tg.id
      assert Contacts.list_contactable_inboxes(account, stranger) == []
    end

    test "whatsapp inboxes come before the others", %{account: account} do
      {:ok, _tg} = Inboxes.create_inbox(account, %{name: "A telegram", channel_type: "telegram"})
      {:ok, _wa} = Inboxes.create_inbox(account, %{name: "Z whatsapp", channel_type: "whatsapp"})

      {:ok, contact} =
        Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511900000001"})

      [tg] = Inboxes.list_inboxes(account) |> Enum.filter(&(&1.channel_type == :telegram))
      {:ok, _} = Contacts.get_or_create_contact_inbox(contact, tg, "4242")

      assert ["Z whatsapp", "A telegram"] =
               account |> Contacts.list_contactable_inboxes(contact) |> Enum.map(& &1.inbox.name)
    end
  end

  describe "Platform.ComposeConversation.create/2" do
    test "opens a conversation assigned to the agent with the outgoing message", %{
      account: account,
      owner: owner
    } do
      {:ok, inbox} = Inboxes.create_inbox(account, %{name: "WA", channel_type: "whatsapp"})

      {:ok, contact} =
        Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511900000001"})

      assert {:ok, conversation} =
               ComposeConversation.create(account, %{
                 user: owner,
                 contact: contact,
                 inbox: inbox,
                 source_id: "5511900000001",
                 content: "Olá Maria"
               })

      conversation = Conversations.get_conversation!(account, conversation.id)
      assert conversation.assignee_id == owner.id
      assert conversation.contact_id == contact.id
      assert conversation.contact_inbox.source_id == "5511900000001"

      assert [%Message{message_type: :outgoing, content: "Olá Maria", sender_id: sender_id}] =
               conversation.messages

      assert sender_id == owner.id
    end

    test "reuses the last conversation when the inbox is locked to a single one", %{
      account: account,
      owner: owner
    } do
      {:ok, inbox} = Inboxes.create_inbox(account, %{name: "WA", channel_type: "whatsapp"})
      inbox = inbox |> Ecto.Changeset.change(lock_to_single_conversation: true) |> Repo.update!()

      {:ok, contact} =
        Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511900000001"})

      attrs = %{user: owner, contact: contact, inbox: inbox, source_id: "5511900000001"}

      {:ok, first} = ComposeConversation.create(account, Map.put(attrs, :content, "1"))
      {:ok, second} = ComposeConversation.create(account, Map.put(attrs, :content, "2"))

      assert first.id == second.id
    end

    test "delivers telegram messages through the sender worker", %{account: account, owner: owner} do
      bypass = Bypass.open()
      Application.put_env(:chatwooter, :telegram_api_base, "http://localhost:#{bypass.port}")
      on_exit(fn -> Application.delete_env(:chatwooter, :telegram_api_base) end)

      Bypass.expect_once(bypass, "POST", "/bottg-token/sendMessage", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 9}}))
      end)

      {:ok, inbox} =
        Inboxes.create_inbox(account, %{
          name: "TG",
          channel_type: "telegram",
          provider_config: %{"bot_token" => "tg-token"}
        })

      {:ok, contact} = Contacts.create_contact(account, %{name: "Maria", email: "m@acme.com"})

      {:ok, conversation} =
        ComposeConversation.create(account, %{
          user: owner,
          contact: contact,
          inbox: inbox,
          source_id: "4242",
          content: "Oi"
        })

      assert [%Message{source_id: "9"}] =
               Conversations.get_conversation!(account, conversation.id).messages
    end

    test "rejects an empty message", %{account: account, owner: owner} do
      {:ok, inbox} = Inboxes.create_inbox(account, %{name: "WA", channel_type: "whatsapp"})

      {:ok, contact} =
        Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511900000001"})

      assert {:error, _} =
               ComposeConversation.create(account, %{
                 user: owner,
                 contact: contact,
                 inbox: inbox,
                 source_id: "5511900000001",
                 content: "  "
               })

      assert Conversations.list_contact_conversations(account, contact) == []
    end
  end
end
