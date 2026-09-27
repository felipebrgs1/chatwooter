defmodule Chatwooter.Notifications.NotificationSubscription do
  @moduledoc "Read mapping of upstream notification_subscriptions; stored enum integers are preserved."
  use Ecto.Schema

  schema "notification_subscriptions" do
    field :user_id, :integer
    field :subscription_type, :integer
    field :subscription_attributes, Chatwooter.Types.JsonValue, redact: true
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :identifier, :string
  end
end
