defmodule Chatwooter.Channels.EmailRecord do
  @moduledoc "Inactive read mapping of restored channel_email; no channel adapter is enabled."
  use Ecto.Schema

  schema "channel_email" do
    field :account_id, :integer
    field :email, :string
    field :forward_to_email, :string
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :imap_enabled, :boolean
    field :imap_address, :string
    field :imap_port, :integer
    field :imap_login, :string
    field :imap_password, :string, redact: true
    field :imap_enable_ssl, :boolean
    field :smtp_enabled, :boolean
    field :smtp_address, :string
    field :smtp_port, :integer
    field :smtp_login, :string
    field :smtp_password, :string, redact: true
    field :smtp_domain, :string
    field :smtp_enable_starttls_auto, :boolean
    field :smtp_authentication, :string
    field :smtp_openssl_verify_mode, :string
    field :smtp_enable_ssl_tls, :boolean
    field :provider_config, Chatwooter.Types.JsonValue, redact: true
    field :provider, :string
    field :imap_authentication, :string
    field :verified_for_sending, :boolean
  end
end
