defmodule Chatwooter.Accounts.AccountUser do
  @moduledoc "Vínculo usuário↔conta com papel (`admin` | `agent`)."

  use Ecto.Schema
  import Ecto.Changeset

  @roles ~w(admin agent)a
  @availabilities ~w(online offline busy)a

  schema "account_users" do
    field :role, Ecto.Enum, values: @roles, default: :agent
    field :availability, Ecto.Enum, values: @availabilities, default: :online
    field :auto_offline, :boolean, default: false

    belongs_to :account, Chatwooter.Accounts.Account
    belongs_to :user, Chatwooter.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:account_id, :user_id, :role, :availability, :auto_offline])
    |> validate_required([:account_id, :user_id, :role])
    |> validate_inclusion(:role, @roles)
    |> validate_inclusion(:availability, @availabilities)
    |> unique_constraint([:account_id, :user_id])
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc "Changeset para atualizar o vínculo (papel, disponibilidade)."
  def membership_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :availability, :auto_offline])
    |> validate_inclusion(:role, @roles)
    |> validate_inclusion(:availability, @availabilities)
  end
end
