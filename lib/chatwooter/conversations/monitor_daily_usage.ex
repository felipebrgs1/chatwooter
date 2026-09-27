defmodule Chatwooter.Conversations.MonitorDailyUsage do
  @moduledoc "Read mapping of upstream conversation_monitor_daily_usages; monitoring stays out of scope."
  use Ecto.Schema

  schema "conversation_monitor_daily_usages" do
    field :account_id, :integer
    field :usage_date, :date
    field :calls_count, :integer
    field :limit_reached_at, :naive_datetime_usec
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
