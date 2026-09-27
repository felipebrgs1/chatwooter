defmodule Chatwooter.Repo.Migrations.CreateCopilotAndPreservedChannelParityTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS vector", "SELECT 1"

    create table(:copilot_threads) do
      add :title, :varchar, null: false
      add :user_id, :bigint, null: false
      add :account_id, :bigint, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :assistant_id, :integer
    end

    create index(:copilot_threads, [:account_id], name: :index_copilot_threads_on_account_id)
    create index(:copilot_threads, [:assistant_id], name: :index_copilot_threads_on_assistant_id)
    create index(:copilot_threads, [:user_id], name: :index_copilot_threads_on_user_id)

    create table(:copilot_messages) do
      add :copilot_thread_id, :bigint, null: false
      add :account_id, :bigint, null: false
      add :message, :jsonb, default: fragment("'{}'::jsonb"), null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :message_type, :integer, default: 0
    end

    create index(:copilot_messages, [:account_id], name: :index_copilot_messages_on_account_id)

    create index(:copilot_messages, [:copilot_thread_id],
             name: :index_copilot_messages_on_copilot_thread_id
           )

    create table(:article_embeddings) do
      add :article_id, :bigint, null: false
      add :term, :text, null: false
      add :embedding, :"vector(1536)"
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:article_embeddings, [:embedding],
             name: :index_article_embeddings_on_embedding,
             using: :ivfflat
           )

    create table(:channel_tiktok) do
      add :account_id, :integer, null: false
      add :business_id, :varchar, null: false
      add :access_token, :varchar, null: false
      add :expires_at, :"timestamp(6)", null: false
      add :refresh_token, :varchar, null: false
      add :refresh_token_expires_at, :"timestamp(6)", null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :provider_name, :varchar
    end

    create unique_index(:channel_tiktok, [:business_id],
             name: :index_channel_tiktok_on_business_id
           )

    create table(:channel_twilio_sms) do
      add :phone_number, :varchar
      add :auth_token, :varchar, null: false
      add :account_sid, :varchar, null: false
      add :account_id, :integer, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :medium, :integer, default: 0
      add :messaging_service_sid, :varchar
      add :api_key_sid, :varchar
      add :content_templates, :jsonb, default: fragment("'{}'::jsonb")
      add :content_templates_last_updated, :"timestamp(6)"
      add :voice_enabled, :boolean, default: false, null: false
      add :twiml_app_sid, :varchar
      add :api_key_secret, :varchar
      add :provider_config, :jsonb, default: fragment("'{}'::jsonb")
    end

    create unique_index(:channel_twilio_sms, [:account_sid, :phone_number],
             name: :index_channel_twilio_sms_on_account_sid_and_phone_number
           )

    create unique_index(:channel_twilio_sms, [:messaging_service_sid],
             name: :index_channel_twilio_sms_on_messaging_service_sid
           )

    create unique_index(:channel_twilio_sms, [:phone_number],
             name: :index_channel_twilio_sms_on_phone_number
           )

    create table(:channel_twitter_profiles) do
      add :profile_id, :varchar, null: false
      add :twitter_access_token, :varchar, null: false
      add :twitter_access_token_secret, :varchar, null: false
      add :account_id, :integer, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :tweets_enabled, :boolean, default: true
    end

    create unique_index(:channel_twitter_profiles, [:account_id, :profile_id],
             name: :index_channel_twitter_profiles_on_account_id_and_profile_id
           )
  end
end
