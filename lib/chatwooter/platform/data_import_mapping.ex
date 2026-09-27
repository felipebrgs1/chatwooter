defmodule Chatwooter.Platform.DataImportMapping do
  @moduledoc "Inactive read mapping of upstream data_import_mappings; transfer uses pg_dump/pg_restore."
  use Ecto.Schema

  schema "data_import_mappings" do
    field :account_id, :integer
    field :data_import_id, :integer
    field :source_provider, :string
    field :source_object_type, :string
    field :source_object_id, :string
    field :chatwoot_record_type, :string
    field :chatwoot_record_id, :integer
    field :metadata, Chatwooter.Types.JsonValue
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
