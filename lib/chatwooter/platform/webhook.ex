defmodule Chatwooter.Platform.Webhook do
  @moduledoc "Read mapping of upstream webhooks; stored enum integers are preserved."
  use Ecto.Schema

  schema "webhooks" do
    field :account_id, :integer
    field :inbox_id, :integer
    field :url, :string
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :webhook_type, :integer
    field :subscriptions, Chatwooter.Types.JsonValue
    field :name, :string
    field :secret, :string, redact: true
  end
end
