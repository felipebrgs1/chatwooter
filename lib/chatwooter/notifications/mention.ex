defmodule Chatwooter.Notifications.Mention do
  @moduledoc "Read mapping of upstream mentions; stored enum integers are preserved."
  use Ecto.Schema

  schema "mentions" do
    field :user_id, :integer
    field :conversation_id, :integer
    field :account_id, :integer
    field :mentioned_at, :naive_datetime_usec
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
