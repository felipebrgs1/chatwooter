defmodule Chatwooter.Channels.TiktokRecord do
  @moduledoc "Inactive read mapping of restored channel_tiktok; no channel adapter is enabled."
  use Ecto.Schema

  schema "channel_tiktok" do
    field :account_id, :integer
    field :business_id, :string
    field :access_token, :string, redact: true
    field :expires_at, :naive_datetime_usec
    field :refresh_token, :string, redact: true
    field :refresh_token_expires_at, :naive_datetime_usec
    field :provider_name, :string
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
