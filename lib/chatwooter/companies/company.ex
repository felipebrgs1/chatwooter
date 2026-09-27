defmodule Chatwooter.Companies.Company do
  @moduledoc "Empresa do CRM (contatos vinculados via `company_id`)."

  use Ecto.Schema
  import Ecto.Changeset

  alias Chatwooter.Accounts.Account
  alias Chatwooter.Contacts.Contact
  alias Chatwooter.Repo

  schema "companies" do
    field :name, :string
    field :domain, :string
    field :description, :string
    field :additional_attributes, :map, default: %{}
    field :custom_attributes, :map, default: %{}
    field :contacts_count, :integer
    field :last_activity_at, :utc_datetime_usec

    belongs_to :account, Account
    has_many :contacts, Contact

    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end

  @doc false
  def changeset(company, attrs) do
    company
    |> cast(attrs, [:name, :domain, :description, :additional_attributes, :custom_attributes])
    |> update_change(:domain, &blank_to_nil/1)
    |> update_change(:description, &blank_to_nil/1)
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 160)
    |> validate_length(:description, max: 2000)
    |> validate_format(
      :domain,
      ~r/^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+$/,
      message: "must be a valid domain"
    )
    |> unique_constraint(:domain, name: :index_companies_on_account_and_domain)
    |> validate_account()
  end

  defp validate_account(changeset) do
    account_id = get_field(changeset, :account_id)

    if account_id && Repo.get(Account, account_id) do
      changeset
    else
      add_error(changeset, :account_id, "does not exist")
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: value)

  defp blank_to_nil(value), do: value
end
