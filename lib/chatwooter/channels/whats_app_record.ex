defmodule Chatwooter.Channels.WhatsAppRecord do
  @moduledoc "Inactive read mapping of restored channel_whatsapp; secrets are not adapter configuration."
  use Ecto.Schema

  schema "channel_whatsapp" do
    field :account_id, :integer
    field :business_management_token, :string, redact: true
    field :phone_number, :string
    field :provider, :string
    field :provider_config, Chatwooter.Types.JsonValue, redact: true
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :message_templates, Chatwooter.Types.JsonValue
    field :message_templates_last_updated, :naive_datetime_usec
    field :phone_number_health, Chatwooter.Types.JsonValue
    field :phone_number_health_checked_at, :naive_datetime_usec
    field :phone_number_health_error, :string
  end
end
