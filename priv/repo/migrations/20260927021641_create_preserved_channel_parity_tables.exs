defmodule Chatwooter.Repo.Migrations.CreatePreservedChannelParityTables do
  use Ecto.Migration

  def change do
    create table(:channel_api) do
      add :account_id, :integer, null: false
      add :webhook_url, :varchar
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :identifier, :varchar
      add :hmac_token, :varchar
      add :hmac_mandatory, :boolean, default: false
      add :additional_attributes, :jsonb, default: fragment("'{}'::jsonb")
      add :secret, :varchar
    end

    create unique_index(:channel_api, [:hmac_token], name: :index_channel_api_on_hmac_token)
    create unique_index(:channel_api, [:identifier], name: :index_channel_api_on_identifier)

    create table(:channel_email) do
      add :account_id, :integer, null: false
      add :email, :varchar, null: false
      add :forward_to_email, :varchar, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :imap_enabled, :boolean, default: false
      add :imap_address, :varchar, default: ""
      add :imap_port, :integer, default: 0
      add :imap_login, :varchar, default: ""
      add :imap_password, :varchar, default: ""
      add :imap_enable_ssl, :boolean, default: true
      add :smtp_enabled, :boolean, default: false
      add :smtp_address, :varchar, default: ""
      add :smtp_port, :integer, default: 0
      add :smtp_login, :varchar, default: ""
      add :smtp_password, :varchar, default: ""
      add :smtp_domain, :varchar, default: ""
      add :smtp_enable_starttls_auto, :boolean, default: true
      add :smtp_authentication, :varchar, default: "login"
      add :smtp_openssl_verify_mode, :varchar, default: "none"
      add :smtp_enable_ssl_tls, :boolean, default: false
      add :provider_config, :jsonb, default: fragment("'{}'::jsonb")
      add :provider, :varchar
      add :imap_authentication, :varchar, default: "plain"
      add :verified_for_sending, :boolean, default: false, null: false
    end

    create unique_index(:channel_email, [:email], name: :index_channel_email_on_email)

    create unique_index(:channel_email, [:forward_to_email],
             name: :index_channel_email_on_forward_to_email
           )

    create table(:channel_facebook_pages, primary_key: false) do
      add :id, :serial, primary_key: true
      add :page_id, :varchar, null: false
      add :user_access_token, :varchar, null: false
      add :page_access_token, :varchar, null: false
      add :account_id, :integer, null: false
      add :created_at, :timestamp, null: false
      add :updated_at, :timestamp, null: false
      add :instagram_id, :varchar
      add :provider_name, :varchar
    end

    create unique_index(:channel_facebook_pages, [:page_id, :account_id],
             name: :index_channel_facebook_pages_on_page_id_and_account_id
           )

    create index(:channel_facebook_pages, [:page_id],
             name: :index_channel_facebook_pages_on_page_id
           )

    create table(:channel_instagram) do
      add :access_token, :varchar, null: false
      add :expires_at, :"timestamp(6)", null: false
      add :account_id, :integer, null: false
      add :instagram_id, :varchar, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :provider_name, :varchar
    end

    create unique_index(:channel_instagram, [:instagram_id],
             name: :index_channel_instagram_on_instagram_id
           )

    create table(:channel_line) do
      add :account_id, :integer, null: false
      add :line_channel_id, :varchar, null: false
      add :line_channel_secret, :varchar, null: false
      add :line_channel_token, :varchar, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create unique_index(:channel_line, [:line_channel_id],
             name: :index_channel_line_on_line_channel_id
           )

    create table(:channel_sms) do
      add :account_id, :integer, null: false
      add :phone_number, :varchar, null: false
      add :provider, :varchar, default: "default"
      add :provider_config, :jsonb, default: fragment("'{}'::jsonb")
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create unique_index(:channel_sms, [:phone_number], name: :index_channel_sms_on_phone_number)
  end
end
