defmodule Chatwooter.ConversationDisplayIdTest do
  use Chatwooter.DataCase, async: true

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes}

  setup do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "DPID"}, owner)

    {:ok, inbox} =
      Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    {:ok, contact} =
      Contacts.get_or_create_contact(account, %{
        name: "Maria",
        phone_number: "+5511999999999"
      })

    %{account: account, inbox: inbox, contact: contact}
  end

  test "database assigns sequential display ids per account", %{
    account: account,
    inbox: inbox
  } do
    assert [[first]] = insert_raw(account.id, inbox.id)
    assert [[second]] = insert_raw(account.id, inbox.id)
    assert second == first + 1
  end

  test "each account has its own display id sequence", %{
    account: account,
    inbox: inbox
  } do
    owner = insert(:user)
    {:ok, other} = Accounts.create_account(%{name: "Other"}, owner)
    {:ok, other_inbox} = Inboxes.create_inbox(other, %{name: "Vendas", channel_type: "whatsapp"})

    assert [[1]] = insert_raw(other.id, other_inbox.id)
    assert [[first]] = insert_raw(account.id, inbox.id)
    assert [[second]] = insert_raw(account.id, inbox.id)
    assert second == first + 1
  end

  test "explicit display ids survive for restored rows", %{account: account, inbox: inbox} do
    assert [[877]] =
             Repo.query!(
               "INSERT INTO conversations (account_id, inbox_id, display_id, created_at, updated_at) VALUES ($1, $2, 877, now(), now()) RETURNING display_id",
               [account.id, inbox.id]
             ).rows
  end

  test "display ids are never reused after deletes", %{account: account, inbox: inbox} do
    assert [[first]] = insert_raw(account.id, inbox.id)
    Repo.query!("DELETE FROM conversations WHERE account_id = $1", [account.id])
    assert [[second]] = insert_raw(account.id, inbox.id)
    assert second > first
  end

  test "open_conversation returns the assigned display id", %{
    account: account,
    inbox: inbox,
    contact: contact
  } do
    {:ok, first} = Conversations.open_conversation(account, inbox, contact, %{})

    {:ok, second_contact} =
      Contacts.get_or_create_contact(account, %{name: "Jose", phone_number: "+5511888888888"})

    {:ok, second} = Conversations.open_conversation(account, inbox, second_contact, %{})

    assert is_integer(first.display_id)
    assert second.display_id == first.display_id + 1
  end

  defp insert_raw(account_id, inbox_id) do
    Repo.query!(
      "INSERT INTO conversations (account_id, inbox_id, created_at, updated_at) VALUES ($1, $2, now(), now()) RETURNING display_id",
      [account_id, inbox_id]
    ).rows
  end
end
