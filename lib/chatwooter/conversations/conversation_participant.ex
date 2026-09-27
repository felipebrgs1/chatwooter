defmodule Chatwooter.Conversations.ConversationParticipant do
  @moduledoc "Read mapping of upstream conversation_participants; stored enum integers are preserved."
  use Ecto.Schema

  schema "conversation_participants" do
    field :account_id, :integer
    field :user_id, :integer
    field :conversation_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
