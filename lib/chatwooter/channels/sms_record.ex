defmodule Chatwooter.Channels.SmsRecord do
  @moduledoc "Inactive read mapping of restored channel_sms; no channel adapter is enabled."
  use Ecto.Schema

  schema "channel_sms" do
    field :account_id, :integer
    field :phone_number, :string
    field :provider, :string
    field :provider_config, Chatwooter.Types.JsonValue, redact: true
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
