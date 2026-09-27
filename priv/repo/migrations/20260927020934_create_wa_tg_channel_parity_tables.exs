defmodule Chatwooter.Repo.Migrations.CreateWaTgChannelParityTables do
  use Ecto.Migration

  def change do
    create table(:channel_whatsapp) do
      add :account_id, :integer, null: false
      add :business_management_token, :text
      add :phone_number, :varchar, null: false
      add :provider, :varchar, default: "default"
      add :provider_config, :jsonb, default: fragment("'{}'::jsonb")
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :message_templates, :jsonb, default: fragment("'{}'::jsonb")
      add :message_templates_last_updated, :timestamp
      add :phone_number_health, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :phone_number_health_checked_at, :"timestamp(6)"
      add :phone_number_health_error, :varchar, size: 500
    end

    create index(:channel_whatsapp, [:phone_number_health_checked_at],
             name: :index_channel_whatsapp_on_phone_number_health_checked_at
           )

    create unique_index(:channel_whatsapp, [:phone_number],
             name: :index_channel_whatsapp_on_phone_number
           )

    create table(:channel_telegram) do
      add :bot_name, :varchar
      add :account_id, :integer, null: false
      add :bot_token, :varchar, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create unique_index(:channel_telegram, [:bot_token],
             name: :index_channel_telegram_on_bot_token
           )
  end
end
