defmodule Chatwooter.Repo.Migrations.CreateDataImportAndPlatformParityTables do
  use Ecto.Migration

  def change do
    create table(:data_imports) do
      add :account_id, :bigint, null: false
      add :data_type, :varchar, null: false
      add :status, :integer, default: 0, null: false
      add :processing_errors, :text
      add :total_records, :integer
      add :processed_records, :integer
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :name, :varchar
      add :source_type, :varchar
      add :source_provider, :varchar
      add :import_types, :jsonb, default: fragment("'[]'::jsonb"), null: false
      add :initiated_by_id, :integer
      add :access_token, :text
      add :source_metadata, :jsonb, default: fragment("'{}'::jsonb"), null: false
      add :stats, :jsonb, default: fragment("'{}'::jsonb"), null: false
      add :cursor, :jsonb, default: fragment("'{}'::jsonb"), null: false
      add :started_at, :"timestamp(6)"
      add :completed_at, :"timestamp(6)"
      add :abandoned_at, :"timestamp(6)"
      add :last_error_at, :"timestamp(6)"
    end

    create index(:data_imports, [:account_id], name: :index_data_imports_on_account_id)
    create index(:data_imports, [:initiated_by_id], name: :index_data_imports_on_initiated_by_id)
    create index(:data_imports, [:source_provider], name: :index_data_imports_on_source_provider)

    create table(:data_import_items) do
      add :data_import_id, :bigint, null: false
      add :source_provider, :varchar, null: false
      add :source_object_type, :varchar, null: false
      add :source_object_id, :varchar, null: false
      add :status, :integer, default: 0, null: false
      add :chatwoot_record_type, :varchar
      add :chatwoot_record_id, :bigint
      add :attempt_count, :integer, default: 0, null: false
      add :last_error_code, :varchar
      add :last_error_message, :text
      add :metadata, :jsonb, default: fragment("'{}'::jsonb"), null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:data_import_items, [:chatwoot_record_type, :chatwoot_record_id],
             name: :idx_data_import_items_on_record
           )

    create unique_index(
             :data_import_items,
             [:data_import_id, :source_object_type, :source_object_id],
             name: :idx_data_import_items_on_import_and_source
           )

    create index(:data_import_items, [:data_import_id],
             name: :index_data_import_items_on_data_import_id
           )

    create index(:data_import_items, [:source_provider, :source_object_type, :source_object_id],
             name: :idx_data_import_items_on_source
           )

    create table(:data_import_mappings) do
      add :account_id, :integer, null: false
      add :data_import_id, :bigint, null: false
      add :source_provider, :varchar, null: false
      add :source_object_type, :varchar, null: false
      add :source_object_id, :varchar, null: false
      add :chatwoot_record_type, :varchar, null: false
      add :chatwoot_record_id, :bigint, null: false
      add :metadata, :jsonb, default: fragment("'{}'::jsonb"), null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create unique_index(
             :data_import_mappings,
             [:account_id, :source_provider, :source_object_type, :source_object_id],
             name: :idx_data_import_mappings_on_account_and_source
           )

    create index(:data_import_mappings, [:chatwoot_record_type, :chatwoot_record_id],
             name: :idx_data_import_mappings_on_record
           )

    create index(:data_import_mappings, [:data_import_id],
             name: :index_data_import_mappings_on_data_import_id
           )

    create table(:data_import_errors) do
      add :data_import_id, :bigint, null: false
      add :data_import_item_id, :bigint
      add :source_object_type, :varchar
      add :source_object_id, :varchar
      add :error_code, :varchar, null: false
      add :message, :text
      add :details, :jsonb, default: fragment("'{}'::jsonb"), null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:data_import_errors, [:data_import_id],
             name: :index_data_import_errors_on_data_import_id
           )

    create index(:data_import_errors, [:data_import_item_id],
             name: :index_data_import_errors_on_data_import_item_id
           )

    create index(:data_import_errors, [:source_object_type, :source_object_id],
             name: :idx_data_import_errors_on_source
           )

    create table(:platform_apps) do
      add :name, :varchar, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create table(:platform_app_permissibles) do
      add :platform_app_id, :bigint, null: false
      add :permissible_type, :varchar, null: false
      add :permissible_id, :bigint, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:platform_app_permissibles, [:permissible_type, :permissible_id],
             name: :index_platform_app_permissibles_on_permissibles
           )

    create unique_index(
             :platform_app_permissibles,
             [:platform_app_id, :permissible_id, :permissible_type],
             name: :unique_permissibles_index
           )

    create index(:platform_app_permissibles, [:platform_app_id],
             name: :index_platform_app_permissibles_on_platform_app_id
           )
  end
end
