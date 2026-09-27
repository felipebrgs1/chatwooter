defmodule Chatwooter.Conversations.MonitorScan do
  @moduledoc "Read mapping of upstream conversation_monitor_scans; monitoring stays out of scope."
  use Ecto.Schema

  schema "conversation_monitor_scans" do
    field :monitor_id, :integer
    field :kind, :string
    field :collection_version, :integer
    field :started_at, :naive_datetime_usec
    field :ended_at, :naive_datetime_usec
    field :cursor, :integer
    field :enumerated_at, :naive_datetime_usec
    field :cancelled_at, :naive_datetime_usec
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
