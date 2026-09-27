defmodule Chatwooter.Inboxes.WorkingHour do
  @moduledoc "Read-compatible mapping of upstream working_hours; IDs and timestamps are preserved."
  use Ecto.Schema

  schema "working_hours" do
    field :day_of_week, :integer
    field :open_hour, :integer
    field :open_minutes, :integer
    field :close_hour, :integer
    field :close_minutes, :integer
    field :closed_all_day, :boolean, default: false
    field :open_all_day, :boolean, default: false
    belongs_to :account, Chatwooter.Accounts.Account
    belongs_to :inbox, Chatwooter.Inboxes.Inbox
    timestamps(type: :naive_datetime_usec, inserted_at: :created_at)
  end
end
