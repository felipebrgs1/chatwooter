defmodule Chatwooter.Conversations.Call do
  @moduledoc "Read mapping of upstream calls; voice calling stays out of scope."
  use Ecto.Schema

  schema "calls" do
    field :account_id, :integer
    field :inbox_id, :integer
    field :conversation_id, :integer
    field :contact_id, :integer
    field :message_id, :integer
    field :accepted_by_agent_id, :integer
    field :provider_call_id, :string
    field :provider, :integer
    field :direction, :integer
    field :status, :string
    field :started_at, :naive_datetime_usec
    field :duration_seconds, :integer
    field :end_reason, :string
    field :meta, Chatwooter.Types.JsonValue
    field :transcript, :string
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
