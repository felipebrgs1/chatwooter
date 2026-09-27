defmodule Chatwooter.Notifications.NotificationSetting do
  @moduledoc "Read mapping of upstream notification_settings; stored enum integers are preserved."
  use Ecto.Schema

  schema "notification_settings" do
    field :account_id, :integer
    field :user_id, :integer
    field :email_flags, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :push_flags, :integer
  end
end
