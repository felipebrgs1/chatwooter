defmodule Chatwooter.Repo.Migrations.CreateStorageAndAuditParityTables do
  use Ecto.Migration

  def change do
    create table(:active_storage_blobs) do
      add :key, :varchar, null: false
      add :filename, :varchar, null: false
      add :content_type, :varchar
      add :metadata, :text
      add :byte_size, :bigint, null: false
      add :checksum, :varchar
      add :created_at, :timestamp, null: false
      add :service_name, :varchar, null: false
    end

    create unique_index(:active_storage_blobs, [:key], name: :index_active_storage_blobs_on_key)

    create table(:active_storage_attachments) do
      add :name, :varchar, null: false
      add :record_type, :varchar, null: false
      add :record_id, :bigint, null: false
      add :blob_id, references(:active_storage_blobs, name: :fk_rails_c3b3935057), null: false
      add :created_at, :timestamp, null: false
    end

    create index(:active_storage_attachments, [:blob_id],
             name: :index_active_storage_attachments_on_blob_id
           )

    create unique_index(:active_storage_attachments, [:record_type, :record_id, :name, :blob_id],
             name: :index_active_storage_attachments_uniqueness
           )

    create table(:active_storage_variant_records) do
      add :blob_id, references(:active_storage_blobs, name: :fk_rails_993965df05), null: false
      add :variation_digest, :varchar, null: false
    end

    create unique_index(:active_storage_variant_records, [:blob_id, :variation_digest],
             name: :index_active_storage_variant_records_uniqueness
           )

    create table(:action_mailbox_inbound_emails) do
      add :status, :integer, null: false, default: 0
      add :message_id, :varchar, null: false
      add :message_checksum, :varchar, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create unique_index(:action_mailbox_inbound_emails, [:message_id, :message_checksum],
             name: :index_action_mailbox_inbound_emails_uniqueness
           )

    create table(:audits) do
      add :auditable_id, :bigint
      add :auditable_type, :varchar
      add :associated_id, :bigint
      add :associated_type, :varchar
      add :user_id, :bigint
      add :user_type, :varchar
      add :username, :varchar
      add :action, :varchar
      add :audited_changes, :jsonb
      add :version, :integer, default: 0
      add :comment, :varchar
      add :remote_address, :varchar
      add :request_uuid, :varchar
      add :created_at, :timestamp
      add :city, :varchar
      add :country, :varchar
      add :country_code, :varchar
    end

    create index(:audits, [:associated_type, :associated_id, :created_at],
             name: :index_audits_on_associated_and_created_at
           )

    create index(:audits, [:associated_type, :associated_id], name: :associated_index)
    create index(:audits, [:auditable_type, :auditable_id, :version], name: :auditable_index)
    create index(:audits, [:created_at], name: :index_audits_on_created_at)
    create index(:audits, [:request_uuid], name: :index_audits_on_request_uuid)
    create index(:audits, [:user_id, :user_type], name: :user_index)
  end
end
