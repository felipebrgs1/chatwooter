defmodule Chatwooter.Repo.Migrations.CreatePlatformAndConversationParityTables do
  use Ecto.Migration

  def change do
    # Trigram search is part of the upstream tags contract; keep the extension on rollback.
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm", "SELECT 1"

    create table(:access_tokens) do
      add :owner_type, :varchar
      add :owner_id, :bigint
      add :token, :varchar
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:access_tokens, [:owner_type, :owner_id],
             name: :index_access_tokens_on_owner_type_and_owner_id
           )

    create unique_index(:access_tokens, [:token], name: :index_access_tokens_on_token)

    create table(:webhooks) do
      add :account_id, :integer
      add :inbox_id, :integer
      add :url, :text
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :webhook_type, :integer, default: 0

      add :subscriptions, :jsonb,
        default:
          fragment(
            "'[\"conversation_status_changed\",\"conversation_updated\",\"conversation_created\",\"contact_created\",\"contact_updated\",\"message_created\",\"message_updated\",\"webwidget_triggered\"]'::jsonb"
          )

      add :name, :varchar
      add :secret, :varchar
    end

    create unique_index(:webhooks, [:account_id, :url],
             name: :index_webhooks_on_account_id_and_url
           )

    create table(:notifications) do
      add :account_id, :bigint, null: false
      add :user_id, :bigint, null: false
      add :notification_type, :integer, null: false
      add :primary_actor_type, :varchar, null: false
      add :primary_actor_id, :bigint, null: false
      add :secondary_actor_type, :varchar
      add :secondary_actor_id, :bigint
      add :read_at, :timestamp
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :snoozed_until, :"timestamp(6)"
      add :last_activity_at, :"timestamp(6)", default: fragment("CURRENT_TIMESTAMP")
      add :meta, :jsonb, default: fragment("'{}'::jsonb")
    end

    create index(:notifications, [:account_id], name: :index_notifications_on_account_id)

    create index(:notifications, [:last_activity_at],
             name: :index_notifications_on_last_activity_at
           )

    create index(:notifications, [:primary_actor_type, :primary_actor_id],
             name: :uniq_primary_actor_per_account_notifications
           )

    create index(:notifications, [:secondary_actor_type, :secondary_actor_id],
             name: :uniq_secondary_actor_per_account_notifications
           )

    create index(:notifications, [:user_id, :account_id, :snoozed_until, :read_at],
             name: :idx_notifications_performance
           )

    create index(:notifications, [:user_id], name: :index_notifications_on_user_id)

    create table(:notification_settings) do
      add :account_id, :integer
      add :user_id, :integer
      add :email_flags, :integer, null: false, default: 0
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :push_flags, :integer, null: false, default: 0
    end

    create unique_index(:notification_settings, [:account_id, :user_id], name: :by_account_user)

    create table(:notification_subscriptions) do
      add :user_id, :bigint, null: false
      add :subscription_type, :integer, null: false
      add :subscription_attributes, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :identifier, :text
    end

    create unique_index(:notification_subscriptions, [:identifier],
             name: :index_notification_subscriptions_on_identifier
           )

    create index(:notification_subscriptions, [:user_id],
             name: :index_notification_subscriptions_on_user_id
           )

    create table(:tags, primary_key: [name: :id, type: :serial]) do
      add :name, :varchar
      add :taggings_count, :integer, default: 0
    end

    create index(:tags, ["lower((name)::text) gin_trgm_ops"],
             name: :tags_name_trgm_idx,
             using: :gin
           )

    create unique_index(:tags, [:name], name: :index_tags_on_name)

    create table(:taggings, primary_key: [name: :id, type: :serial]) do
      add :tag_id, :integer
      add :taggable_type, :varchar
      add :taggable_id, :integer
      add :tagger_type, :varchar
      add :tagger_id, :integer
      add :context, :varchar, size: 128
      add :created_at, :timestamp
    end

    create index(:taggings, [:context], name: :index_taggings_on_context)

    create unique_index(
             :taggings,
             [:tag_id, :taggable_id, :taggable_type, :context, :tagger_id, :tagger_type],
             name: :taggings_idx
           )

    create index(:taggings, [:tag_id], name: :index_taggings_on_tag_id)

    create index(:taggings, [:taggable_id, :taggable_type, :context],
             name: :index_taggings_on_taggable_id_and_taggable_type_and_context
           )

    create index(:taggings, [:taggable_id, :taggable_type, :tagger_id, :context],
             name: :taggings_idy
           )

    create index(:taggings, [:taggable_id], name: :index_taggings_on_taggable_id)
    create index(:taggings, [:taggable_type], name: :index_taggings_on_taggable_type)

    create index(:taggings, [:tagger_id, :tagger_type],
             name: :index_taggings_on_tagger_id_and_tagger_type
           )

    create index(:taggings, [:tagger_id], name: :index_taggings_on_tagger_id)

    create table(:conversation_participants) do
      add :account_id, :bigint, null: false
      add :user_id, :bigint, null: false
      add :conversation_id, :bigint, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:conversation_participants, [:account_id],
             name: :index_conversation_participants_on_account_id
           )

    create index(:conversation_participants, [:conversation_id],
             name: :index_conversation_participants_on_conversation_id
           )

    create unique_index(:conversation_participants, [:user_id, :conversation_id],
             name: :index_conversation_participants_on_user_id_and_conversation_id
           )

    create index(:conversation_participants, [:user_id],
             name: :index_conversation_participants_on_user_id
           )

    create table(:csat_survey_responses) do
      add :account_id, :bigint, null: false
      add :conversation_id, :bigint, null: false
      add :message_id, :bigint, null: false
      add :rating, :integer, null: false
      add :feedback_message, :text
      add :contact_id, :bigint, null: false
      add :assigned_agent_id, :bigint
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :csat_review_notes, :text
      add :review_notes_updated_at, :"timestamp(6)"
      add :review_notes_updated_by_id, :bigint
    end

    create index(:csat_survey_responses, [:account_id],
             name: :index_csat_survey_responses_on_account_id
           )

    create index(:csat_survey_responses, [:assigned_agent_id],
             name: :index_csat_survey_responses_on_assigned_agent_id
           )

    create index(:csat_survey_responses, [:contact_id],
             name: :index_csat_survey_responses_on_contact_id
           )

    create index(:csat_survey_responses, [:conversation_id],
             name: :index_csat_survey_responses_on_conversation_id
           )

    create unique_index(:csat_survey_responses, [:message_id],
             name: :index_csat_survey_responses_on_message_id
           )

    create index(:csat_survey_responses, [:review_notes_updated_by_id],
             name: :index_csat_survey_responses_on_review_notes_updated_by_id
           )

    create table(:custom_filters) do
      add :name, :varchar, null: false
      add :filter_type, :integer, null: false, default: 0
      add :query, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :account_id, :bigint, null: false
      add :user_id, :bigint, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:custom_filters, [:account_id], name: :index_custom_filters_on_account_id)
    create index(:custom_filters, [:user_id], name: :index_custom_filters_on_user_id)

    create table(:custom_roles) do
      add :name, :varchar
      add :description, :varchar
      add :account_id, :bigint, null: false
      add :permissions, {:array, :text}, default: []
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:custom_roles, [:account_id], name: :index_custom_roles_on_account_id)

    create table(:dashboard_apps) do
      add :title, :varchar, null: false
      add :content, :jsonb, default: fragment("'[]'::jsonb")
      add :account_id, :bigint, null: false
      add :user_id, :bigint
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:dashboard_apps, [:account_id], name: :index_dashboard_apps_on_account_id)
    create index(:dashboard_apps, [:user_id], name: :index_dashboard_apps_on_user_id)

    create table(:integrations_hooks) do
      add :status, :integer, default: 1
      add :inbox_id, :integer
      add :account_id, :integer
      add :app_id, :varchar
      add :hook_type, :integer, default: 0
      add :reference_id, :varchar
      add :access_token, :varchar
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :settings, :jsonb, default: fragment("'{}'::jsonb")
    end

    create table(:automation_rules) do
      add :account_id, :bigint, null: false
      add :name, :varchar, null: false
      add :description, :text
      add :event_name, :varchar, null: false
      add :conditions, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :actions, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :active, :boolean, null: false, default: true
      add :execution_delay, :integer
    end

    create index(:automation_rules, [:account_id], name: :index_automation_rules_on_account_id)

    create table(:macros) do
      add :account_id, :bigint, null: false
      add :name, :varchar, null: false
      add :visibility, :integer, default: 0
      add :created_by_id, :bigint
      add :updated_by_id, :bigint
      add :actions, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:macros, [:account_id], name: :index_macros_on_account_id)

    create table(:mentions) do
      add :user_id, :bigint, null: false
      add :conversation_id, :bigint, null: false
      add :account_id, :bigint, null: false
      add :mentioned_at, :timestamp, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:mentions, [:account_id], name: :index_mentions_on_account_id)
    create index(:mentions, [:conversation_id], name: :index_mentions_on_conversation_id)

    create unique_index(:mentions, [:user_id, :conversation_id],
             name: :index_mentions_on_user_id_and_conversation_id
           )

    create index(:mentions, [:user_id], name: :index_mentions_on_user_id)

    create table(:reporting_events) do
      add :name, :varchar
      add :value, :float
      add :account_id, :integer
      add :inbox_id, :integer
      add :user_id, :integer
      add :conversation_id, :integer
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :value_in_business_hours, :float
      add :event_start_time, :timestamp
      add :event_end_time, :timestamp
    end

    create index(:reporting_events, [:account_id, :name, :created_at],
             name: :reporting_events__account_id__name__created_at
           )

    create index(:reporting_events, [:account_id, :name, :inbox_id, :created_at],
             name: :index_reporting_events_for_response_distribution
           )

    create index(:reporting_events, [:account_id], name: :index_reporting_events_on_account_id)

    create index(:reporting_events, [:conversation_id],
             name: :index_reporting_events_on_conversation_id
           )

    create index(:reporting_events, [:created_at], name: :index_reporting_events_on_created_at)
    create index(:reporting_events, [:inbox_id], name: :index_reporting_events_on_inbox_id)
    create index(:reporting_events, [:name], name: :index_reporting_events_on_name)
    create index(:reporting_events, [:user_id], name: :index_reporting_events_on_user_id)

    create table(:sla_policies) do
      add :name, :varchar, null: false
      add :first_response_time_threshold, :float
      add :next_response_time_threshold, :float
      add :only_during_business_hours, :boolean, default: false
      add :account_id, :bigint, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :description, :varchar
      add :resolution_time_threshold, :float
    end

    create index(:sla_policies, [:account_id], name: :index_sla_policies_on_account_id)

    create table(:applied_slas) do
      add :account_id, :bigint, null: false
      add :sla_policy_id, :bigint, null: false
      add :conversation_id, :bigint, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :sla_status, :integer, default: 0
      add :completed_at, :"timestamp(6)"
    end

    create unique_index(:applied_slas, [:account_id, :sla_policy_id, :conversation_id],
             name: :index_applied_slas_on_account_sla_policy_conversation
           )

    create index(:applied_slas, [:account_id], name: :index_applied_slas_on_account_id)
    create index(:applied_slas, [:conversation_id], name: :index_applied_slas_on_conversation_id)
    create index(:applied_slas, [:sla_policy_id], name: :index_applied_slas_on_sla_policy_id)

    create table(:sla_events) do
      add :applied_sla_id, :bigint, null: false
      add :conversation_id, :bigint, null: false
      add :account_id, :bigint, null: false
      add :sla_policy_id, :bigint, null: false
      add :inbox_id, :bigint, null: false
      add :event_type, :integer
      add :meta, :jsonb, default: fragment("'{}'::jsonb")
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:sla_events, [:account_id], name: :index_sla_events_on_account_id)
    create index(:sla_events, [:applied_sla_id], name: :index_sla_events_on_applied_sla_id)
    create index(:sla_events, [:conversation_id], name: :index_sla_events_on_conversation_id)
    create index(:sla_events, [:inbox_id], name: :index_sla_events_on_inbox_id)
    create index(:sla_events, [:sla_policy_id], name: :index_sla_events_on_sla_policy_id)
  end
end
