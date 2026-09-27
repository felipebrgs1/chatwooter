defmodule Chatwooter.Repo.Migrations.CreateImportRunsAndErrors do
  use Ecto.Migration

  def change do
    create table(:import_runs) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :source_account_id, :bigint, null: false
      add :status, :string, null: false, default: "pending"
      add :attempts, :integer, null: false, default: 0
      add :processed_count, :integer, null: false, default: 0
      add :failed_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:import_runs, [:account_id])

    create constraint(:import_runs, :import_runs_valid_state,
             check:
               "source_account_id > 0 AND attempts >= 0 AND processed_count >= 0 AND failed_count >= 0 AND status IN ('pending', 'running', 'completed', 'failed')"
           )

    create table(:import_errors) do
      add :import_run_id, references(:import_runs, on_delete: :delete_all), null: false
      add :source_table, :string, null: false
      add :source_id, :bigint, null: false
      add :code, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:import_errors, [:import_run_id, :source_table, :source_id],
             name: :import_errors_source_index
           )

    create constraint(:import_errors, :import_errors_safe_fields,
             check:
               "source_id > 0 AND source_table = 'users' AND code IN ('invalid_source', 'invalid_agent', 'source_changed', 'stale_mapping', 'conflict')"
           )
  end
end
