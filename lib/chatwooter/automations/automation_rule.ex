defmodule Chatwooter.Automations.AutomationRule do
  @moduledoc "Read mapping of upstream automation_rules; stored enum integers are preserved."
  use Ecto.Schema

  schema "automation_rules" do
    field :account_id, :integer
    field :name, :string
    field :description, :string
    field :event_name, :string
    field :conditions, Chatwooter.Types.JsonValue
    field :actions, Chatwooter.Types.JsonValue
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :active, :boolean
    field :execution_delay, :integer
  end
end
