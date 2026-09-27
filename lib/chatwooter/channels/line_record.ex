defmodule Chatwooter.Channels.LineRecord do
  @moduledoc "Inactive read mapping of restored channel_line; no channel adapter is enabled."
  use Ecto.Schema

  schema "channel_line" do
    field :account_id, :integer
    field :line_channel_id, :string
    field :line_channel_secret, :string, redact: true
    field :line_channel_token, :string, redact: true
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
