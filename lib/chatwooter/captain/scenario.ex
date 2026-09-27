defmodule Chatwooter.Captain.Scenario do
  @moduledoc "Read mapping of upstream captain_scenarios; Captain stays out of scope."
  use Ecto.Schema

  schema "captain_scenarios" do
    field :title, :string
    field :description, :string
    field :instruction, :string
    field :tools, Chatwooter.Types.JsonValue
    field :enabled, :boolean
    field :assistant_id, :integer
    field :account_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
