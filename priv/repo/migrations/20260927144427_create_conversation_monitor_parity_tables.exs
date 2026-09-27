defmodule Chatwooter.Repo.Migrations.CreateConversationMonitorParityTables do
  use Ecto.Migration

  def change do
    create table(:conversation_monitors) do
      add :account_id, references(:accounts, type: :bigint, on_delete: :delete_all), null: false

      add :user_id, references(:users, type: :bigint, on_delete: :nilify_all)
      add :name, :varchar, null: false
      add :condition, :text, null: false
      add :model, :varchar, null: false
      add :threshold, :float, null: false
      add :history_since, :"timestamp(6)", null: false
      add :paused_at, :"timestamp(6)"
      add :resumed_at, :"timestamp(6)"
      add :deleted_at, :"timestamp(6)"
      add :data_revision, :bigint, default: 0, null: false
      add :collection_version, :bigint, default: 0, null: false
      add :recheck_requested_at, :"timestamp(6)"
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :icon, :varchar, default: "chat-3-line", null: false
      add :icon_color, :varchar, default: "#3B82F6", null: false
    end

    create index(:conversation_monitors, [:account_id],
             name: :index_conversation_monitors_on_account_id
           )

    create index(:conversation_monitors, [:user_id],
             name: :index_conversation_monitors_on_user_id
           )

    create table(:conversation_monitor_evaluations) do
      add :account_id, references(:accounts, type: :bigint, on_delete: :delete_all), null: false

      add :monitor_id,
          references(:conversation_monitors, type: :bigint, on_delete: :delete_all),
          null: false

      add :conversation_id, references(:conversations, type: :bigint, on_delete: :delete_all),
        null: false

      add :status, :varchar, default: "pending", null: false
      add :input_revision, :bigint, default: 0, null: false
      add :generation, :bigint, default: 0, null: false
      add :requested_version, :bigint
      add :score, :float
      add :model, :varchar
      add :error_code, :varchar
      add :matched_at, :"timestamp(6)"
      add :evaluated_at, :"timestamp(6)"
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:conversation_monitor_evaluations, [:account_id],
             name: :index_conversation_monitor_evaluations_on_account_id
           )

    create index(:conversation_monitor_evaluations, [:conversation_id],
             name: :index_conversation_monitor_evaluations_on_conversation_id
           )

    create unique_index(:conversation_monitor_evaluations, [:monitor_id, :conversation_id],
             name: :index_monitor_evaluations_unique
           )

    create index(:conversation_monitor_evaluations, [:monitor_id, :status, :conversation_id],
             name: :index_monitor_evaluations_status
           )

    create index(:conversation_monitor_evaluations, [:monitor_id],
             name: :index_conversation_monitor_evaluations_on_monitor_id
           )

    create table(:conversation_monitor_scans) do
      add :monitor_id,
          references(:conversation_monitors, type: :bigint, on_delete: :delete_all),
          null: false

      add :kind, :varchar, null: false
      add :collection_version, :bigint, null: false
      add :started_at, :"timestamp(6)", null: false
      add :ended_at, :"timestamp(6)", null: false
      add :cursor, :bigint, default: 0, null: false
      add :enumerated_at, :"timestamp(6)"
      add :cancelled_at, :"timestamp(6)"
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create unique_index(:conversation_monitor_scans, [:monitor_id, :collection_version, :kind],
             name: :index_monitor_scans_version_kind
           )

    create unique_index(:conversation_monitor_scans, [:monitor_id],
             name: :index_monitor_scans_initial,
             where: "((kind)::text = 'initial'::text)"
           )

    create table(:conversation_monitor_work_items) do
      add :account_id, references(:accounts, type: :bigint, on_delete: :delete_all), null: false

      add :conversation_id, references(:conversations, type: :bigint, on_delete: :delete_all),
        null: false

      add :revision, :bigint, default: 0, null: false
      add :processed_revision, :bigint, default: 0, null: false
      add :full_history_revision, :bigint, default: 0, null: false
      add :generation, :bigint, default: 0, null: false
      add :due_at, :"timestamp(6)"
      add :lease_token, :varchar
      add :lease_expires_at, :"timestamp(6)"
      add :attempts, :integer, default: 0, null: false
      add :error_code, :varchar
      add :requested_at, :"timestamp(6)"
      add :activity_at, :"timestamp(6)"
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:conversation_monitor_work_items, [:account_id],
             name: :index_conversation_monitor_work_items_on_account_id
           )

    create unique_index(:conversation_monitor_work_items, [:conversation_id],
             name: :index_conversation_monitor_work_items_on_conversation_id
           )

    create index(:conversation_monitor_work_items, [:due_at],
             name: :index_monitor_work_due,
             where: "(due_at IS NOT NULL)"
           )

    create table(:conversation_monitor_daily_usages) do
      add :account_id, references(:accounts, type: :bigint, on_delete: :delete_all), null: false

      add :usage_date, :date, null: false
      add :calls_count, :integer, default: 0, null: false
      add :limit_reached_at, :"timestamp(6)"
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create unique_index(:conversation_monitor_daily_usages, [:account_id, :usage_date],
             name: :index_monitor_daily_usage_unique
           )

    create constraint(:conversation_monitor_daily_usages, :monitor_daily_usage_nonnegative,
             check: "calls_count >= 0"
           )

    create table(:calls) do
      add :account_id, :bigint, null: false
      add :inbox_id, :bigint, null: false
      add :conversation_id, :bigint, null: false
      add :contact_id, :bigint, null: false
      add :message_id, :bigint
      add :accepted_by_agent_id, :bigint
      add :provider_call_id, :varchar, null: false
      add :provider, :integer, default: 0, null: false
      add :direction, :integer, null: false
      add :status, :varchar, default: "ringing", null: false
      add :started_at, :"timestamp(6)"
      add :duration_seconds, :integer
      add :end_reason, :varchar
      add :meta, :jsonb, default: fragment("'{}'::jsonb")
      add :transcript, :text
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:calls, [:account_id, :contact_id],
             name: :index_calls_on_account_id_and_contact_id
           )

    create index(:calls, [:account_id, :conversation_id],
             name: :index_calls_on_account_id_and_conversation_id
           )

    create index(:calls, [:account_id, :created_at],
             name: :index_calls_on_account_id_and_created_at
           )

    create index(:calls, [:message_id], name: :index_calls_on_message_id)

    create unique_index(:calls, [:provider, :provider_call_id],
             name: :index_calls_on_provider_and_provider_call_id
           )
  end
end
