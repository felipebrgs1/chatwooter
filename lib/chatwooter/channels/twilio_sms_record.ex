defmodule Chatwooter.Channels.TwilioSmsRecord do
  @moduledoc "Inactive read mapping of restored channel_twilio_sms; no channel adapter is enabled."
  use Ecto.Schema

  schema "channel_twilio_sms" do
    field :phone_number, :string
    field :auth_token, :string, redact: true
    field :account_sid, :string
    field :account_id, :integer
    field :medium, :integer
    field :messaging_service_sid, :string
    field :api_key_sid, :string
    field :content_templates, Chatwooter.Types.JsonValue
    field :content_templates_last_updated, :naive_datetime_usec
    field :voice_enabled, :boolean
    field :twiml_app_sid, :string
    field :api_key_secret, :string, redact: true
    field :provider_config, Chatwooter.Types.JsonValue, redact: true
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
