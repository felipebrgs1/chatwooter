defmodule Chatwooter.Conversations.ReportingEvent do
  @moduledoc "Read mapping of upstream reporting_events; stored enum integers are preserved."
  use Ecto.Schema

  schema "reporting_events" do
    field :name, :string
    field :value, :float
    field :account_id, :integer
    field :inbox_id, :integer
    field :user_id, :integer
    field :conversation_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :value_in_business_hours, :float
    field :event_start_time, :naive_datetime_usec
    field :event_end_time, :naive_datetime_usec
  end
end
