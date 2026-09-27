defmodule Chatwooter.Conversations.Outcome do
  @moduledoc "Read mapping of upstream conversation_outcomes; Captain reporting stays out of scope."
  use Ecto.Schema

  schema "conversation_outcomes" do
    field :account_id, :integer
    field :assistant_id, :integer
    field :conversation_id, :integer
    field :inbox_id, :integer
    field :first_captain_reply_at, :naive_datetime_usec
    field :last_captain_reply_at, :naive_datetime_usec
    field :captain_reply_count, :integer
    field :first_human_reply_at, :naive_datetime_usec
    field :handoff_at, :naive_datetime_usec
    field :handoff_reason_category, :string
    field :resolved_at, :naive_datetime_usec
    field :csat_rating, :integer
    field :csat_received_at, :naive_datetime_usec
    field :episode_trigger, :string
    field :started_at, :naive_datetime_usec
    field :ended_at, :naive_datetime_usec
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
