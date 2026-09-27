defmodule Chatwooter.Captain.Assistant do
  @moduledoc "Read mapping of upstream captain_assistants; Captain stays out of scope."
  use Ecto.Schema

  schema "captain_assistants" do
    field :name, :string
    field :account_id, :integer
    field :description, :string
    field :config, Chatwooter.Types.JsonValue
    field :response_guidelines, Chatwooter.Types.JsonValue
    field :guardrails, Chatwooter.Types.JsonValue
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
