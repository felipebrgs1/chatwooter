defmodule Chatwooter.Companies do
  @moduledoc "Bounded context de empresas (espelho do `Company` do Chatwoot)."

  import Ecto.Changeset, only: [get_change: 2]
  import Ecto.Query, warn: false
  alias Chatwooter.Repo

  alias Chatwooter.Accounts.Account
  alias Chatwooter.Companies.Company
  alias Chatwooter.Contacts
  alias Chatwooter.Contacts.Contact

  @doc "Lista as empresas da conta com contagem de contatos."
  def list_companies(%Account{id: account_id}) do
    Repo.all(
      from c in Company,
        where: c.account_id == ^account_id,
        left_join: ct in assoc(c, :contacts),
        group_by: c.id,
        select_merge: %{contacts_count: count(ct.id)},
        order_by: [asc: c.name]
    )
  end

  @doc "Busca uma empresa da conta (levanta se for de outra conta)."
  def get_company!(%Account{id: account_id}, id) do
    Repo.get_by!(Company, id: id, account_id: account_id)
  end

  @doc "Cadastra uma empresa."
  def create_company(%Account{} = account, attrs) do
    %Company{account_id: account.id}
    |> Company.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Atualiza uma empresa (renomear sincroniza os contatos vinculados)."
  def update_company(%Company{} = company, attrs) do
    changeset = Company.changeset(company, attrs)

    with {:ok, company} <- Repo.update(changeset) do
      if get_change(changeset, :name) do
        Contacts.sync_company_name(company.id, company.name)
      end

      {:ok, company}
    end
  end

  @doc "Remove uma empresa (contatos vinculados são desvinculados)."
  def delete_company(%Company{} = company) do
    Repo.transaction(fn ->
      Repo.update_all(from(c in Contact, where: c.company_id == ^company.id),
        set: [company_id: nil]
      )

      case Repo.delete(company) do
        {:ok, deleted} -> deleted
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc "Changeset para formulários (sem persistir)."
  def change_company(%Company{} = company, attrs \\ %{}) do
    Company.changeset(company, attrs)
  end

  @doc "Define um atributo customizado (merge, como no Chatwoot)."
  def set_custom_attribute(%Company{} = company, key, value) when is_binary(key) do
    custom = Map.put(company.custom_attributes || %{}, key, value)

    company
    |> Company.changeset(%{custom_attributes: custom})
    |> Repo.update()
  end

  @doc "Remove um atributo customizado."
  def remove_custom_attribute(%Company{} = company, key) when is_binary(key) do
    custom = Map.delete(company.custom_attributes || %{}, key)

    company
    |> Company.changeset(%{custom_attributes: custom})
    |> Repo.update()
  end

  @doc "Contatos vinculados à empresa."
  def list_company_contacts(%Company{} = company) do
    Contacts.list_company_contacts(company)
  end
end
