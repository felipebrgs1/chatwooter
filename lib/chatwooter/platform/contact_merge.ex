defmodule Chatwooter.Platform.ContactMerge do
  @moduledoc """
  Mescla dois contatos da mesma conta, como o `ContactMergeAction` do Chatwoot:
  o `base` fica, o `mergee` é absorvido (conversas, mensagens, inboxes, notas) e apagado.
  """

  alias Chatwooter.Accounts.Account
  alias Chatwooter.Contacts
  alias Chatwooter.Contacts.Contact
  alias Chatwooter.Conversations
  alias Chatwooter.Repo

  def merge(%Account{id: account_id}, %Contact{} = base, %Contact{} = mergee)
      when base.account_id == account_id and mergee.account_id == account_id and
             base.id != mergee.id do
    Repo.transaction(fn ->
      :ok = Conversations.reassign_contact(account_id, mergee.id, base.id)

      case Contacts.merge_into(base, mergee) do
        {:ok, merged} -> merged
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def merge(_account, _base, _mergee), do: {:error, :invalid_contacts}
end
