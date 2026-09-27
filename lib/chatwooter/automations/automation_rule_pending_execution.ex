defmodule Chatwooter.Automations.AutomationRulePendingExecution do
  @moduledoc "Read mapping of upstream automation_rule_pending_executions; stored values are preserved."
  use Ecto.Schema

  schema "automation_rule_pending_executions" do
    field :automation_rule_id, :integer
    field :conversation_id, :integer
    field :account_id, :integer
    field :message_id, :integer
    field :due_at, :naive_datetime_usec
    field :episode_key, :string
    field :status, :integer
    field :skip_reason, :string
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
