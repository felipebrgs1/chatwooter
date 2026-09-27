defmodule Chatwooter.Imports.ImportMapping do
  @moduledoc "Immutable mapping from an upstream ID to a destination record, scoped to one account."

  use Ecto.Schema
  import Ecto.Changeset

  schema "import_mappings" do
    field :source_table, :string
    field :old_id, :integer
    field :new_id, :integer

    belongs_to :account, Chatwooter.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  def changeset(mapping, attrs) do
    mapping
    |> cast(attrs, [:source_table, :old_id, :new_id])
    |> validate_required([:source_table, :old_id, :new_id])
    |> validate_number(:old_id, greater_than: 0)
    |> validate_number(:new_id, greater_than: 0)
    |> check_constraint(:old_id, name: :import_mappings_positive_ids)
    |> check_constraint(:source_table, name: :import_mappings_supported_tables)
    |> foreign_key_constraint(:account_id)
    |> unique_constraint([:account_id, :source_table, :old_id],
      name: :import_mappings_source_index
    )
    |> unique_constraint([:account_id, :source_table, :new_id],
      name: :import_mappings_target_index
    )
  end
end
