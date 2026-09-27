defmodule Chatwooter.Conversations.SlaEvent do
  @moduledoc "Read mapping of upstream sla_events; stored enum integers are preserved."
  use Ecto.Schema

  schema "sla_events" do
    field :applied_sla_id, :integer
    field :conversation_id, :integer
    field :account_id, :integer
    field :sla_policy_id, :integer
    field :inbox_id, :integer
    field :event_type, :integer
    field :meta, Chatwooter.Types.JsonValue
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
