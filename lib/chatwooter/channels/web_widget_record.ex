defmodule Chatwooter.Channels.WebWidgetRecord do
  @moduledoc "Inactive read mapping of restored channel_web_widgets."
  use Ecto.Schema

  schema "channel_web_widgets" do
    field :website_url, :string
    field :account_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :website_token, :string, redact: true
    field :widget_color, :string
    field :welcome_title, :string
    field :welcome_tagline, :string
    field :feature_flags, :integer
    field :reply_time, :integer
    field :hmac_token, :string, redact: true
    field :pre_chat_form_enabled, :boolean
    field :pre_chat_form_options, Chatwooter.Types.JsonValue
    field :hmac_mandatory, :boolean
    field :continuity_via_email, :boolean
    field :allowed_domains, :string
  end
end
