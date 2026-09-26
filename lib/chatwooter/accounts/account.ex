defmodule Chatwooter.Accounts.Account do
  @moduledoc "Tenant raiz do Chatwooter (equivale a `Account` no Chatwoot Rails)."

  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :name, :string
    field :locale, :string, default: "pt-BR"
    field :settings, :map, default: %{}

    has_many :account_users, Chatwooter.Accounts.AccountUser
    has_many :users, through: [:account_users, :user]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :locale, :settings])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 160)
  end
end
