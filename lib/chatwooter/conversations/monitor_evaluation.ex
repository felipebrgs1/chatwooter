defmodule Chatwooter.Conversations.MonitorEvaluation do
  @moduledoc "Read mapping of upstream conversation_monitor_evaluations; monitoring stays out of scope."
  use Ecto.Schema

  schema "conversation_monitor_evaluations" do
    field :account_id, :integer
    field :monitor_id, :integer
    field :conversation_id, :integer
    field :status, :string
    field :input_revision, :integer
    field :generation, :integer
    field :requested_version, :integer
    field :score, :float
    field :model, :string
    field :error_code, :string
    field :matched_at, :naive_datetime_usec
    field :evaluated_at, :naive_datetime_usec
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
