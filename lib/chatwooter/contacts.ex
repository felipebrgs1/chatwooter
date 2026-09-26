defmodule Chatwooter.Contacts do
  @moduledoc "Bounded context de contatos."

  import Ecto.Query, warn: false
  alias Chatwooter.Repo

  alias Chatwooter.Accounts.Account
  alias Chatwooter.Contacts.{Contact, ContactInbox}
  alias Chatwooter.Inboxes.Inbox

  @doc """
  Busca por telefone dentro da conta; cria se não existir (idempotente).
  """
  def get_or_create_contact(%Account{} = account, attrs) do
    phone = Map.get(attrs, :phone_number) || Map.get(attrs, "phone_number")

    case phone && Repo.get_by(Contact, account_id: account.id, phone_number: phone) do
      nil ->
        %Contact{account_id: account.id}
        |> Contact.changeset(attrs)
        |> Repo.insert()

      %Contact{} = contact ->
        {:ok, contact}
    end
  end

  @doc "Busca a identidade do contato no inbox (origem do ingest de webhooks)."
  def fetch_contact_inbox(%Inbox{id: inbox_id}, source_id) do
    case Repo.get_by(ContactInbox, inbox_id: inbox_id, source_id: source_id) do
      %ContactInbox{} = contact_inbox -> {:ok, contact_inbox}
      nil -> {:error, :not_found}
    end
  end

  def get_or_create_contact_inbox(%Contact{} = contact, %Inbox{} = inbox, source_id) do
    case Repo.get_by(ContactInbox,
           contact_id: contact.id,
           inbox_id: inbox.id,
           source_id: source_id
         ) do
      nil ->
        %ContactInbox{}
        |> ContactInbox.changeset(%{
          contact_id: contact.id,
          inbox_id: inbox.id,
          source_id: source_id
        })
        |> Repo.insert()

      %ContactInbox{} = contact_inbox ->
        {:ok, contact_inbox}
    end
  end
end
