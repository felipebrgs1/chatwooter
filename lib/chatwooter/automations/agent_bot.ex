defmodule Chatwooter.Automations.AgentBot do
  @moduledoc "Read mapping of upstream agent_bots; stored values are preserved."
  use Ecto.Schema

  schema "agent_bots" do
    field :name, :string
    field :description, :string
    field :outgoing_url, :string
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :account_id, :integer
    field :bot_type, :integer
    field :bot_config, Chatwooter.Types.JsonValue, redact: true
    field :secret, :string, redact: true
  end
end
