defmodule Chatwooter.Platform.DataImportItem do
  @moduledoc "Inactive read mapping of upstream data_import_items; transfer uses pg_dump/pg_restore."
  use Ecto.Schema

  schema "data_import_items" do
    field :data_import_id, :integer
    field :source_provider, :string
    field :source_object_type, :string
    field :source_object_id, :string
    field :status, :integer
    field :chatwoot_record_type, :string
    field :chatwoot_record_id, :integer
    field :attempt_count, :integer
    field :last_error_code, :string
    field :last_error_message, :string
    field :metadata, Chatwooter.Types.JsonValue
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
