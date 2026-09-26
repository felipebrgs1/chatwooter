defmodule Chatwooter.Repo.Migrations.CreateMessaging do
  use Ecto.Migration

  def change do
    create table(:inboxes) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :channel_type, :string, null: false
      add :provider_config, :map, null: false, default: %{}
      add :greeting_message, :string

      timestamps(type: :utc_datetime)
    end

    create index(:inboxes, [:account_id])

    create table(:contacts) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :phone_number, :string
      add :email, :string
      add :additional_attributes, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:contacts, [:account_id])
    # NULLs são distintos no Postgres: vários contatos sem telefone são permitidos.
    create unique_index(:contacts, [:account_id, :phone_number])

    create table(:contact_inboxes) do
      add :contact_id, references(:contacts, on_delete: :delete_all), null: false
      add :inbox_id, references(:inboxes, on_delete: :delete_all), null: false
      add :source_id, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:contact_inboxes, [:inbox_id, :source_id])
    create unique_index(:contact_inboxes, [:contact_id, :inbox_id])

    create table(:conversations) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :inbox_id, references(:inboxes, on_delete: :delete_all), null: false
      add :contact_inbox_id, references(:contact_inboxes, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "open"
      add :last_activity_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:conversations, [:account_id, :status])

    create table(:messages) do
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :inbox_id, references(:inboxes, on_delete: :delete_all), null: false
      add :sender_id, references(:users, on_delete: :nilify_all)
      add :message_type, :string, null: false, default: "incoming"
      add :content, :text, null: false
      add :private, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:conversation_id])
  end
end
