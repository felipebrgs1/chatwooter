defmodule Chatwooter.Repo.Migrations.CreateImportMappings do
  use Ecto.Migration

  def change do
    create table(:import_mappings) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :source_table, :string, null: false
      add :old_id, :bigint, null: false
      add :new_id, :bigint, null: false

      timestamps(type: :utc_datetime)
    end

    create constraint(:import_mappings, :import_mappings_positive_ids,
             check: "old_id > 0 AND new_id > 0"
           )

    create constraint(:import_mappings, :import_mappings_supported_tables,
             check: "source_table IN ('accounts', 'users', 'teams', 'inboxes')"
           )

    create unique_index(:import_mappings, [:account_id, :source_table, :old_id],
             name: :import_mappings_source_index
           )

    create unique_index(:import_mappings, [:account_id, :source_table, :new_id],
             name: :import_mappings_target_index
           )
  end
end
