defmodule Chatwooter.Platform.DataImport do
  @moduledoc "Inactive read mapping of upstream data_imports; transfer uses pg_dump/pg_restore."
  use Ecto.Schema

  schema "data_imports" do
    field :account_id, :integer
    field :data_type, :string
    field :status, :integer
    field :processing_errors, :string
    field :total_records, :integer
    field :processed_records, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :name, :string
    field :source_type, :string
    field :source_provider, :string
    field :import_types, Chatwooter.Types.JsonValue
    field :initiated_by_id, :integer
    field :access_token, :string, redact: true
    field :source_metadata, Chatwooter.Types.JsonValue
    field :stats, Chatwooter.Types.JsonValue
    field :cursor, Chatwooter.Types.JsonValue
    field :started_at, :naive_datetime_usec
    field :completed_at, :naive_datetime_usec
    field :abandoned_at, :naive_datetime_usec
    field :last_error_at, :naive_datetime_usec
  end
end
