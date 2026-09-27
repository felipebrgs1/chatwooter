defmodule Chatwooter.Channels.TelegramRecord do
  @moduledoc "Inactive read mapping of restored channel_telegram; secrets are not adapter configuration."
  use Ecto.Schema

  schema "channel_telegram" do
    field :bot_name, :string
    field :account_id, :integer
    field :bot_token, :string, redact: true
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
