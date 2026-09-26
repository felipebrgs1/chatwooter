defmodule Chatwooter.Contacts.Contact do
  @moduledoc "Contato do CRM mínimo (deduplicado por telefone dentro da conta)."

  use Ecto.Schema
  import Ecto.Changeset

  schema "contacts" do
    field :name, :string
    field :phone_number, :string
    field :email, :string
    field :additional_attributes, :map, default: %{}

    belongs_to :account, Chatwooter.Accounts.Account
    belongs_to :company, Chatwooter.Companies.Company
    has_many :contact_inboxes, Chatwooter.Contacts.ContactInbox

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:name, :phone_number, :email, :additional_attributes, :company_id])
    |> foreign_key_constraint(:company_id)
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 160)
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> unique_constraint(:phone_number, name: :contacts_account_id_phone_number_index)
    |> foreign_key_constraint(:account_id)
  end
end
