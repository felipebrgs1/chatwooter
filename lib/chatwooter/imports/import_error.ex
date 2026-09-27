defmodule Chatwooter.Imports.ImportError do
  @moduledoc "A sanitized source ID and allowlisted error code, never source payload or credentials."

  use Ecto.Schema

  schema "import_errors" do
    field :source_table, :string
    field :source_id, :integer
    field :code, :string

    belongs_to :import_run, Chatwooter.Imports.ImportRun

    timestamps(type: :utc_datetime)
  end
end
