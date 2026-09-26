defmodule Chatwooter.Contacts do
  @moduledoc "Bounded context de contatos."

  import Ecto.Query, warn: false
  alias Chatwooter.Repo

  alias Chatwooter.Accounts.Account
  alias Chatwooter.Companies.Company
  alias Chatwooter.Contacts.{Contact, ContactInbox}
  alias Chatwooter.Inboxes.Inbox

  @doc "Lista os contatos da conta em ordem alfabética."
  def list_contacts(%Account{id: account_id}) do
    Contact
    |> where([c], c.account_id == ^account_id)
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  @doc "Busca um contato da conta (levanta se for de outra conta)."
  def get_contact!(%Account{id: account_id}, id) do
    Repo.get_by!(Contact, id: id, account_id: account_id)
  end

  @doc "Cadastra um contato manualmente (nome + telefone/email)."
  def create_contact(%Account{} = account, attrs) do
    %Contact{account_id: account.id}
    |> Contact.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Atualiza um contato."
  def update_contact(%Contact{} = contact, attrs) do
    contact
    |> Contact.changeset(attrs)
    |> Repo.update()
  end

  @doc "Remove um contato."
  def delete_contact(%Contact{} = contact), do: Repo.delete(contact)

  @doc "Changeset para formulários (sem persistir)."
  def change_contact(%Contact{} = contact, attrs \\ %{}) do
    Contact.changeset(contact, attrs)
  end

  @doc "Contatos vinculados a uma empresa."
  def list_company_contacts(%Company{id: company_id}) do
    Contact
    |> where([c], c.company_id == ^company_id)
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  @doc "Vincula um contato à empresa (sincroniza o nome da empresa)."
  def assign_company(%Contact{} = contact, %Company{id: company_id, name: name}) do
    contact
    |> Contact.changeset(%{
      company_id: company_id,
      additional_attributes: Map.put(contact.additional_attributes || %{}, "company_name", name)
    })
    |> Repo.update()
  end

  @doc "Atualiza o nome denormalizado da empresa nos contatos vinculados."
  def sync_company_name(company_id, name) do
    contacts = Repo.all(from c in Contact, where: c.company_id == ^company_id)

    Enum.each(contacts, fn contact ->
      contact
      |> Contact.changeset(%{
        additional_attributes: Map.put(contact.additional_attributes || %{}, "company_name", name)
      })
      |> Repo.update!()
    end)

    {:ok, length(contacts)}
  end

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
