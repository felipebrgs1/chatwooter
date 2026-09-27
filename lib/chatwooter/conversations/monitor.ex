defmodule Chatwooter.Conversations.Monitor do
  @moduledoc "Read mapping of upstream conversation_monitors; monitoring stays out of scope."
  use Ecto.Schema

  schema "conversation_monitors" do
    field :account_id, :integer
    field :user_id, :integer
    field :name, :string
    field :condition, :string
    field :model, :string
    field :threshold, :float
    field :history_since, :naive_datetime_usec
    field :paused_at, :naive_datetime_usec
    field :resumed_at, :naive_datetime_usec
    field :deleted_at, :naive_datetime_usec
    field :data_revision, :integer
    field :collection_version, :integer
    field :recheck_requested_at, :naive_datetime_usec
    field :icon, :string
    field :icon_color, :string
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
