defmodule Chatwooter.Inboxes.InboxCapacityLimit do
  @moduledoc "Read mapping of upstream inbox_capacity_limits; stored values are preserved."
  use Ecto.Schema

  schema "inbox_capacity_limits" do
    field :agent_capacity_policy_id, :integer
    field :inbox_id, :integer
    field :conversation_limit, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
