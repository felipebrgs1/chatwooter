defmodule Chatwooter.Conversations.ReportingEventsRollup do
  @moduledoc "Read mapping of upstream reporting_events_rollups; stored values are preserved."
  use Ecto.Schema

  schema "reporting_events_rollups" do
    field :account_id, :integer
    field :date, :date
    field :dimension_type, :string
    field :dimension_id, :integer
    field :metric, :string
    field :count, :integer
    field :sum_value, :float
    field :sum_value_business_hours, :float
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
