defmodule Chatwooter.Channels.InstagramRecord do
  @moduledoc "Inactive read mapping of restored channel_instagram; no channel adapter is enabled."
  use Ecto.Schema

  schema "channel_instagram" do
    field :access_token, :string, redact: true
    field :expires_at, :naive_datetime_usec
    field :account_id, :integer
    field :instagram_id, :string
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :provider_name, :string
  end
end
