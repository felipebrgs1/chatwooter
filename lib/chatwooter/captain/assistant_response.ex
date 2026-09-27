defmodule Chatwooter.Captain.AssistantResponse do
  @moduledoc "Read mapping of upstream captain_assistant_responses; Captain stays out of scope."
  use Ecto.Schema

  schema "captain_assistant_responses" do
    field :question, :string
    field :answer, :string
    field :embedding, Pgvector.Ecto.Vector
    field :assistant_id, :integer
    field :documentable_id, :integer
    field :account_id, :integer
    field :status, :integer
    field :documentable_type, :string
    field :edited, :boolean
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
