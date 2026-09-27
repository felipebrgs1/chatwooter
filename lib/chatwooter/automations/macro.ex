defmodule Chatwooter.Automations.Macro do
  @moduledoc "Read mapping of upstream macros; stored enum integers are preserved."
  use Ecto.Schema

  schema "macros" do
    field :account_id, :integer
    field :name, :string
    field :visibility, :integer
    field :created_by_id, :integer
    field :updated_by_id, :integer
    field :actions, Chatwooter.Types.JsonValue
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
