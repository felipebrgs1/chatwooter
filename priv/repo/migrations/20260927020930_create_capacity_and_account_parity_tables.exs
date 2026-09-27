defmodule Chatwooter.Repo.Migrations.CreateCapacityAndAccountParityTables do
  use Ecto.Migration

  def change do
    create table(:account_saml_settings) do
      add :account_id, :bigint, null: false
      add :sso_url, :varchar
      add :certificate, :text
      add :sp_entity_id, :varchar
      add :idp_entity_id, :varchar
      add :role_mappings, :json, default: fragment("'{}'::json")
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:account_saml_settings, [:account_id],
             name: :index_account_saml_settings_on_account_id
           )

    create table(:agent_capacity_policies) do
      add :account_id, :bigint, null: false
      add :name, :varchar, size: 255, null: false
      add :description, :text
      add :exclusion_rules, :jsonb, default: fragment("'{}'::jsonb"), null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:agent_capacity_policies, [:account_id],
             name: :index_agent_capacity_policies_on_account_id
           )

    create table(:assignment_policies) do
      add :account_id, :bigint, null: false
      add :name, :varchar, size: 255, null: false
      add :description, :text
      add :assignment_order, :integer, default: 0, null: false
      add :conversation_priority, :integer, default: 0, null: false
      add :fair_distribution_limit, :integer, default: 100, null: false
      add :fair_distribution_window, :integer, default: 3600, null: false
      add :enabled, :boolean, default: true, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :exclude_older_than_hours, :integer, default: 168
    end

    create unique_index(:assignment_policies, [:account_id, :name],
             name: :index_assignment_policies_on_account_id_and_name
           )

    create index(:assignment_policies, [:account_id],
             name: :index_assignment_policies_on_account_id
           )

    create index(:assignment_policies, [:enabled], name: :index_assignment_policies_on_enabled)

    create table(:inbox_assignment_policies) do
      add :inbox_id, :bigint, null: false
      add :assignment_policy_id, :bigint, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:inbox_assignment_policies, [:assignment_policy_id],
             name: :index_inbox_assignment_policies_on_assignment_policy_id
           )

    create unique_index(:inbox_assignment_policies, [:inbox_id],
             name: :index_inbox_assignment_policies_on_inbox_id
           )

    create table(:inbox_capacity_limits) do
      add :agent_capacity_policy_id, :bigint, null: false
      add :inbox_id, :bigint, null: false
      add :conversation_limit, :integer, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create unique_index(:inbox_capacity_limits, [:agent_capacity_policy_id, :inbox_id],
             name: :idx_on_agent_capacity_policy_id_inbox_id_71c7ec4caf
           )

    create index(:inbox_capacity_limits, [:agent_capacity_policy_id],
             name: :index_inbox_capacity_limits_on_agent_capacity_policy_id
           )

    create index(:inbox_capacity_limits, [:inbox_id],
             name: :index_inbox_capacity_limits_on_inbox_id
           )

    create table(:leaves) do
      add :account_id, :bigint, null: false
      add :user_id, :bigint, null: false
      add :start_date, :date, null: false
      add :end_date, :date, null: false
      add :leave_type, :integer, default: 0, null: false
      add :status, :integer, default: 0, null: false
      add :reason, :text
      add :approved_by_id, :bigint
      add :approved_at, :"timestamp(6)"
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:leaves, [:account_id, :status], name: :index_leaves_on_account_id_and_status)

    create index(:leaves, [:account_id], name: :index_leaves_on_account_id)

    create index(:leaves, [:approved_by_id], name: :index_leaves_on_approved_by_id)

    create index(:leaves, [:user_id], name: :index_leaves_on_user_id)

    create table(:folders) do
      add :account_id, :integer, null: false
      add :category_id, :integer, null: false
      add :name, :varchar
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end
  end
end
