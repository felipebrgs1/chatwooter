defmodule Chatwooter.Repo.Migrations.CreateAttachments do
  use Ecto.Migration

  def change do
    create table(:attachments) do
      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :file_type, :string, null: false
      add :key, :string, null: false
      add :url, :string, null: false
      add :content_type, :string
      add :size_bytes, :integer
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:attachments, [:message_id])
    create unique_index(:attachments, [:message_id, :key])
  end
end
