defmodule Chatwooter.Accounts.Account do
  @moduledoc "Tenant raiz do Chatwooter (equivale a `Account` no Chatwoot Rails)."

  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :name, :string
    field :locale, :integer, default: 0
    field :domain, :string
    field :support_email, :string
    field :feature_flags, :integer
    field :auto_resolve_duration, :integer
    field :limits, Chatwooter.Types.JsonValue
    field :custom_attributes, Chatwooter.Types.JsonValue
    field :status, :integer
    field :internal_attributes, Chatwooter.Types.JsonValue
    field :settings, Chatwooter.Types.JsonValue, default: %{}
    field :feature_flags_ext_1, :integer

    has_many :account_users, Chatwooter.Accounts.AccountUser
    has_many :users, through: [:account_users, :user]

    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :locale, :settings])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 160)
  end
end
