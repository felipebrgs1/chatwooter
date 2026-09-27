defmodule Chatwooter.Repo.Migrations.CreateAutomationAndConfigurationParityTables do
  use Ecto.Migration

  def change do
    create table(:agent_bots) do
      add :name, :varchar
      add :description, :varchar
      add :outgoing_url, :varchar
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :account_id, :bigint
      add :bot_type, :integer, default: 0
      add :bot_config, :jsonb, default: fragment("'{}'::jsonb")
      add :secret, :varchar
    end

    create index(:agent_bots, [:account_id], name: :index_agent_bots_on_account_id)

    create table(:agent_bot_inboxes) do
      add :inbox_id, :integer
      add :agent_bot_id, :integer
      add :status, :integer, default: 0
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :account_id, :integer
    end

    create table(:automation_rule_pending_executions) do
      add :automation_rule_id, :bigint, null: false
      add :conversation_id, :bigint, null: false
      add :account_id, :bigint, null: false
      add :message_id, :bigint
      add :due_at, :"timestamp(6)", null: false
      add :episode_key, :varchar, null: false
      add :status, :integer, null: false, default: 0
      add :skip_reason, :varchar
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:automation_rule_pending_executions, [:account_id],
             name: :index_automation_rule_pending_executions_on_account_id
           )

    create unique_index(
             :automation_rule_pending_executions,
             [:automation_rule_id, :conversation_id, :episode_key],
             name: :uniq_automation_pending_execution_episode
           )

    create index(:automation_rule_pending_executions, [:automation_rule_id],
             name: :index_automation_rule_pending_executions_on_automation_rule_id
           )

    create index(:automation_rule_pending_executions, [:conversation_id],
             name: :index_automation_rule_pending_executions_on_conversation_id
           )

    create index(:automation_rule_pending_executions, [:status, :due_at],
             name: :index_automation_rule_pending_executions_on_status_and_due_at
           )

    create index(:automation_rule_pending_executions, [:status, :updated_at],
             name: :index_automation_pending_executions_on_status_and_updated_at
           )

    create table(:email_templates) do
      add :name, :varchar, null: false
      add :body, :text, null: false
      add :account_id, :integer
      add :template_type, :integer, default: 1
      add :locale, :integer, null: false, default: 0
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :inbox_id, :integer
    end

    create unique_index(:email_templates, [:account_id, :name, :template_type, :locale],
             name: :index_email_templates_on_account_scope,
             where: "(account_id IS NOT NULL) AND (inbox_id IS NULL)"
           )

    create unique_index(:email_templates, [:inbox_id, :name, :template_type, :locale],
             name: :index_email_templates_on_inbox_scope,
             where: "(inbox_id IS NOT NULL)"
           )

    create index(:email_templates, [:inbox_id], name: :index_email_templates_on_inbox_id)

    create unique_index(:email_templates, [:name, :template_type, :locale],
             name: :index_email_templates_on_installation_scope,
             where: "(account_id IS NULL) AND (inbox_id IS NULL)"
           )

    create table(:installation_configs) do
      add :name, :varchar, null: false
      add :serialized_value, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :locked, :boolean, null: false, default: true
    end

    create unique_index(:installation_configs, [:name, :created_at],
             name: :index_installation_configs_on_name_and_created_at
           )

    create unique_index(:installation_configs, [:name], name: :index_installation_configs_on_name)

    create table(:platform_banners) do
      add :banner_message, :text, null: false
      add :banner_type, :integer, null: false, default: 0
      add :active, :boolean, null: false, default: true
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create table(:reporting_events_rollups) do
      add :account_id, :integer, null: false
      add :date, :date, null: false
      add :dimension_type, :varchar, null: false
      add :dimension_id, :bigint, null: false
      add :metric, :varchar, null: false
      add :count, :bigint, null: false, default: 0
      add :sum_value, :float, null: false, default: 0.0
      add :sum_value_business_hours, :float, null: false, default: 0.0
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create unique_index(
             :reporting_events_rollups,
             [:account_id, :date, :dimension_type, :dimension_id, :metric],
             name: :index_rollup_unique_key
           )

    create index(:reporting_events_rollups, [:account_id, :dimension_type, :date],
             name: :index_rollup_summary
           )

    create index(:reporting_events_rollups, [:account_id, :metric, :date],
             name: :index_rollup_timeseries
           )
  end
end
