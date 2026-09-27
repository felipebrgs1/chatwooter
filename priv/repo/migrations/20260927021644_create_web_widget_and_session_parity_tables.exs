defmodule Chatwooter.Repo.Migrations.CreateWebWidgetAndSessionParityTables do
  use Ecto.Migration

  def change do
    create table(:channel_web_widgets, primary_key: [name: :id, type: :serial]) do
      add :website_url, :varchar
      add :account_id, :integer
      add :created_at, :timestamp, null: false
      add :updated_at, :timestamp, null: false
      add :website_token, :varchar
      add :widget_color, :varchar, default: "#1f93ff"
      add :welcome_title, :varchar
      add :welcome_tagline, :varchar
      add :feature_flags, :integer, null: false, default: 7
      add :reply_time, :integer, default: 0
      add :hmac_token, :varchar
      add :pre_chat_form_enabled, :boolean, default: false
      add :pre_chat_form_options, :jsonb, default: fragment("'{}'::jsonb")
      add :hmac_mandatory, :boolean, default: false
      add :continuity_via_email, :boolean, null: false, default: true
      add :allowed_domains, :text, default: ""
    end

    create unique_index(:channel_web_widgets, [:hmac_token],
             name: :index_channel_web_widgets_on_hmac_token
           )

    create unique_index(:channel_web_widgets, [:website_token],
             name: :index_channel_web_widgets_on_website_token
           )

    create table(:user_sessions) do
      add :user_id, references(:users, type: :bigint, on_delete: :nothing), null: false
      add :client_id, :varchar, null: false
      add :ip_address, :varchar
      add :user_agent, :varchar
      add :browser_name, :varchar
      add :browser_version, :varchar
      add :device_name, :varchar
      add :platform_name, :varchar
      add :platform_version, :varchar
      add :city, :varchar
      add :country, :varchar
      add :country_code, :varchar
      add :last_activity_at, :"timestamp(6)"
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create unique_index(:user_sessions, [:user_id, :client_id],
             name: :index_user_sessions_on_user_id_and_client_id
           )

    create index(:user_sessions, [:user_id], name: :index_user_sessions_on_user_id)
  end
end
