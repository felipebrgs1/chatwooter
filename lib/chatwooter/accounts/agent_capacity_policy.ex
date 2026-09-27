defmodule Chatwooter.Accounts.AgentCapacityPolicy do
  @moduledoc "Read mapping of upstream agent_capacity_policies; stored values are preserved."
  use Ecto.Schema

  schema "agent_capacity_policies" do
    field :account_id, :integer
    field :name, :string
    field :description, :string
    field :exclusion_rules, Chatwooter.Types.JsonValue
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
