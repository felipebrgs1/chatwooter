defmodule Chatwooter.Accounts.AccountUser do
  @moduledoc "Vínculo usuário↔conta com papel (`administrator` | `agent`)."

  use Ecto.Schema
  import Ecto.Changeset

  @roles ~w(administrator agent)a
  @availabilities ~w(online offline busy)a

  schema "account_users" do
    field :role, Ecto.Enum, values: [agent: 0, administrator: 1], default: :agent
    field :inviter_id, :integer
    field :active_at, :utc_datetime_usec
    field :availability, Ecto.Enum, values: [online: 0, offline: 1, busy: 2], default: :online
    field :auto_offline, :boolean, default: true
    field :custom_role_id, :integer
    field :agent_capacity_policy_id, :integer

    belongs_to :account, Chatwooter.Accounts.Account
    belongs_to :user, Chatwooter.Accounts.User

    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:account_id, :user_id, :role, :availability, :auto_offline])
    |> validate_required([:account_id, :user_id, :role])
    |> validate_inclusion(:role, @roles)
    |> validate_inclusion(:availability, @availabilities)
    |> unique_constraint([:account_id, :user_id], name: :uniq_user_id_per_account_id)
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
