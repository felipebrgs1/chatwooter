defmodule Chatwooter.Conversations.AppliedSla do
  @moduledoc "Read mapping of upstream applied_slas; stored enum integers are preserved."
  use Ecto.Schema

  schema "applied_slas" do
    field :account_id, :integer
    field :sla_policy_id, :integer
    field :conversation_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :sla_status, :integer
    field :completed_at, :naive_datetime_usec
  end
end
