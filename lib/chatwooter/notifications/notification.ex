defmodule Chatwooter.Notifications.Notification do
  @moduledoc "Read mapping of upstream notifications; stored enum integers are preserved."
  use Ecto.Schema

  schema "notifications" do
    field :account_id, :integer
    field :user_id, :integer
    field :notification_type, :integer
    field :primary_actor_type, :string
    field :primary_actor_id, :integer
    field :secondary_actor_type, :string
    field :secondary_actor_id, :integer
    field :read_at, :naive_datetime_usec
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :snoozed_until, :naive_datetime_usec
    field :last_activity_at, :naive_datetime_usec
    field :meta, Chatwooter.Types.JsonValue
  end
end
