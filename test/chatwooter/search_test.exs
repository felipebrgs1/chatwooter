defmodule Chatwooter.SearchTest do
  @moduledoc "Busca global (SearchService do Chatwoot, sem advanced_search): contatos, conversas e mensagens."
  use Chatwooter.DataCase, async: true

  import Chatwooter.AccountsFixtures

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes, Repo}

  setup do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, user)
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})
    %{user: user, account: account, inbox: inbox}
  end

  defp contact(account, attrs) do
    {:ok, contact} =
      Contacts.create_contact(
        account,
        Map.merge(%{phone_number: "+55119#{System.unique_integer([:positive])}"}, attrs)
      )

    contact
  end

  defp conversation(account, inbox, contact) do
    {:ok, conv} = Conversations.open_conversation(account, inbox, contact)
    conv
  end

  defp other_account do
    {:ok, account} = Accounts.create_account(%{name: "Other"}, user_fixture())
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Other", channel_type: "whatsapp"})
    {account, inbox}
  end

  describe "search_contacts/3" do
    test "matches name, email, phone and identifier with ILIKE", %{account: account} do
      maria = contact(account, %{name: "Maria Silva"})
      by_email = contact(account, %{name: "Ana", email: "MARIA@acme.com"})
      by_phone = contact(account, %{name: "Bob", phone_number: "+5511987654321"})
      _nope = contact(account, %{name: "João"})

      ids = account |> Contacts.search_contacts("maria") |> Enum.map(& &1.id)
      assert Enum.sort(ids) == Enum.sort([maria.id, by_email.id])

      assert [%{id: id}] = Contacts.search_contacts(account, "98765")
      assert id == by_phone.id
    end

    test "is scoped by account and orders by last activity (nulls last)", %{account: account} do
      {other, _inbox} = other_account()
      _foreign = contact(other, %{name: "Maria Outra"})

      old = contact(account, %{name: "Maria Old"})
      recent = contact(account, %{name: "Maria Recent"})
      never = contact(account, %{name: "Maria Never"})

      Repo.update!(Ecto.Changeset.change(old, last_activity_at: ~U[2024-01-01 00:00:00.000000Z]))

      Repo.update!(
        Ecto.Changeset.change(recent, last_activity_at: ~U[2025-01-01 00:00:00.000000Z])
      )

      assert account |> Contacts.search_contacts("maria") |> Enum.map(& &1.id) ==
               [recent.id, old.id, never.id]
    end

    test "pages 15 at a time", %{account: account} do
      for i <- 1..16, do: contact(account, %{name: "Page #{i}"})

      assert length(Contacts.search_contacts(account, "page")) == 15
      assert length(Contacts.search_contacts(account, "page", 2)) == 1
    end
  end

  describe "search_conversations/3" do
    test "matches display id and contact fields, scoped by account", %{
      account: account,
      inbox: inbox
    } do
      maria = contact(account, %{name: "Maria Silva", email: "maria@acme.com"})
      joao = contact(account, %{name: "João"})
      conv_maria = conversation(account, inbox, maria)
      conv_joao = conversation(account, inbox, joao)

      {other, other_inbox} = other_account()
      conversation(other, other_inbox, contact(other, %{name: "Maria Outra"}))

      assert [found] = Conversations.search_conversations(account, "acme.com")
      assert found.id == conv_maria.id
      assert found.contact_inbox.contact.name == "Maria Silva"
      assert found.inbox.name == "Vendas"

      assert conv_joao.id in (account
                              |> Conversations.search_conversations(
                                to_string(conv_joao.display_id)
                              )
                              |> Enum.map(& &1.id))
    end

    test "orders newest first", %{account: account, inbox: inbox} do
      first = conversation(account, inbox, contact(account, %{name: "Maria A"}))
      second = conversation(account, inbox, contact(account, %{name: "Maria B"}))

      Repo.update!(Ecto.Changeset.change(first, inserted_at: ~U[2024-01-01 00:00:00.000000Z]))

      assert account |> Conversations.search_conversations("maria") |> Enum.map(& &1.id) ==
               [second.id, first.id]
    end
  end

  describe "search_messages/3" do
    test "matches content with ILIKE within the account's last 3 months", %{
      account: account,
      inbox: inbox,
      user: user
    } do
      conv = conversation(account, inbox, contact(account, %{name: "Maria"}))
      {:ok, incoming} = Conversations.add_message(conv, %{content: "Preciso do BOLETO"})

      {:ok, outgoing} =
        Conversations.add_message(conv, %{
          content: "Segue o boleto",
          message_type: "outgoing",
          sender_id: user.id
        })

      {:ok, old} = Conversations.add_message(conv, %{content: "boleto antigo"})
      {:ok, _other} = Conversations.add_message(conv, %{content: "bom dia"})

      Repo.update!(
        Ecto.Changeset.change(old,
          inserted_at: DateTime.add(DateTime.utc_now(), -100, :day)
        )
      )

      {other, other_inbox} = other_account()
      other_conv = conversation(other, other_inbox, contact(other, %{name: "Xy"}))
      Conversations.add_message(other_conv, %{content: "boleto de outra conta"})

      results = Conversations.search_messages(account, "boleto")
      assert Enum.map(results, & &1.id) == [outgoing.id, incoming.id]

      [out, inc] = results
      assert out.sender.id == user.id
      assert out.inbox.name == "Vendas"
      assert out.conversation.display_id == conv.display_id
      assert inc.sender == nil
      assert inc.conversation.contact_inbox.contact.name == "Maria"
    end
  end
end
