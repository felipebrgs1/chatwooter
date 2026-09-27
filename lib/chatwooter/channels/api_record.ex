defmodule Chatwooter.Channels.ApiRecord do
  @moduledoc "Inactive read mapping of restored channel_api; no channel adapter is enabled."
  use Ecto.Schema

  schema "channel_api" do
    field :account_id, :integer
    field :webhook_url, :string
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :identifier, :string
    field :hmac_token, :string, redact: true
    field :hmac_mandatory, :boolean
    field :additional_attributes, Chatwooter.Types.JsonValue
    field :secret, :string, redact: true
  end
end
