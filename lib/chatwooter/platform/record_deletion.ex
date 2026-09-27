defmodule Chatwooter.Platform.RecordDeletion do
  @moduledoc "Coordinates scoped cleanup formerly provided by local cascade constraints."

  alias Chatwooter.{Contacts, Conversations, Inboxes, Repo}

  def delete_inbox(account, id) do
    inbox = Inboxes.get_inbox!(account, id)

    Repo.transaction(fn ->
      with {:ok, _} <- Conversations.delete_inbox_data(account.id, inbox.id),
           {:ok, _} <- Contacts.delete_inbox_data(inbox),
           {:ok, deleted} <- Inboxes.delete_inbox(account, inbox.id) do
        deleted
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def delete_contact(account, id) do
    contact = Contacts.get_contact!(account, id)

    Repo.transaction(fn ->
      with {:ok, _} <- Conversations.delete_contact_data(account.id, contact.id),
           {:ok, deleted} <- Contacts.delete_contact(contact) do
        deleted
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end
end
