defmodule Chatwooter.Contacts.Contact do
  @moduledoc "Contato do CRM mínimo (deduplicado por telefone dentro da conta)."

  use Ecto.Schema
  import Ecto.Changeset

  alias Chatwooter.Accounts.Account
  alias Chatwooter.Companies.Company
  alias Chatwooter.Contacts.ContactInbox
  alias Chatwooter.Repo

  schema "contacts" do
    field :name, :string, default: ""
    field :phone_number, :string
    field :email, :string
    field :additional_attributes, :map, default: %{}

    field :identifier, :string
    field :custom_attributes, :map, default: %{}
    field :last_activity_at, :utc_datetime_usec
    field :contact_type, :integer, default: 0
    field :middle_name, :string, default: ""
    field :last_name, :string, default: ""
    field :location, :string, default: ""
    field :country_code, :string, default: ""
    field :blocked, :boolean, default: false

    belongs_to :account, Account
    belongs_to :company, Company
    has_many :contact_inboxes, ContactInbox

    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end

  @doc false
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:name, :phone_number, :email, :additional_attributes, :company_id])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 160)
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> unsafe_validate_unique([:account_id, :phone_number], Repo, error_key: :phone_number)
    |> unique_constraint(:email, name: :uniq_email_per_account_contact)
    |> unique_constraint(:identifier, name: :uniq_identifier_per_account_contact)
    |> validate_account()
    |> validate_company()
  end

  defp validate_account(changeset) do
    account_id = get_field(changeset, :account_id)

    if account_id && Repo.get(Account, account_id) do
      changeset
    else
      add_error(changeset, :account_id, "does not exist")
    end
  end

  defp validate_company(changeset) do
    case get_field(changeset, :company_id) do
      nil ->
        changeset

      company_id ->
        if Repo.get_by(Company, id: company_id, account_id: get_field(changeset, :account_id)) do
          changeset
        else
          add_error(changeset, :company_id, "does not belong to this account")
        end
    end
  end
end
