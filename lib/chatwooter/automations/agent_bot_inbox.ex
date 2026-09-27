defmodule Chatwooter.Automations.AgentBotInbox do
  @moduledoc "Read mapping of upstream agent_bot_inboxes; stored values are preserved."
  use Ecto.Schema

  schema "agent_bot_inboxes" do
    field :inbox_id, :integer
    field :agent_bot_id, :integer
    field :status, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :account_id, :integer
  end
end
