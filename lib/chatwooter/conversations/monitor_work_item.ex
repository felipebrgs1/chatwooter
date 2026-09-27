defmodule Chatwooter.Conversations.MonitorWorkItem do
  @moduledoc "Read mapping of upstream conversation_monitor_work_items; monitoring stays out of scope."
  use Ecto.Schema

  schema "conversation_monitor_work_items" do
    field :account_id, :integer
    field :conversation_id, :integer
    field :revision, :integer
    field :processed_revision, :integer
    field :full_history_revision, :integer
    field :generation, :integer
    field :due_at, :naive_datetime_usec
    field :lease_token, :string
    field :lease_expires_at, :naive_datetime_usec
    field :attempts, :integer
    field :error_code, :string
    field :requested_at, :naive_datetime_usec
    field :activity_at, :naive_datetime_usec
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
