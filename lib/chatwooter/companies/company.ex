defmodule Chatwooter.Companies.Company do
  @moduledoc "Empresa do CRM (contatos vinculados via `company_id`)."

  use Ecto.Schema
  import Ecto.Changeset

  schema "companies" do
    field :name, :string
    field :domain, :string
    field :description, :string
    field :additional_attributes, :map, default: %{}
    field :custom_attributes, :map, default: %{}
    field :contacts_count, :integer, virtual: true, default: 0

    belongs_to :account, Chatwooter.Accounts.Account
    has_many :contacts, Chatwooter.Contacts.Contact

    timestamps(type: :utc_datetime)
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
    |> unique_constraint(:domain, name: :companies_account_id_domain_index)
    |> foreign_key_constraint(:account_id)
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: value)

  defp blank_to_nil(value), do: value
end
