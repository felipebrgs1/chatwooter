defmodule Chatwooter.Platform.DataImportError do
  @moduledoc "Inactive read mapping of upstream data_import_errors; transfer uses pg_dump/pg_restore."
  use Ecto.Schema

  schema "data_import_errors" do
    field :data_import_id, :integer
    field :data_import_item_id, :integer
    field :source_object_type, :string
    field :source_object_id, :string
    field :error_code, :string
    field :message, :string
    field :details, Chatwooter.Types.JsonValue
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
