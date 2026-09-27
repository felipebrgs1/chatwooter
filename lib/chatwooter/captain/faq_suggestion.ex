defmodule Chatwooter.Captain.FaqSuggestion do
  @moduledoc "Read mapping of upstream captain_faq_suggestions; Captain stays out of scope."
  use Ecto.Schema

  schema "captain_faq_suggestions" do
    field :question, :string
    field :answer, :string
    field :embedding, Pgvector.Ecto.Vector
    field :assistant_id, :integer
    field :account_id, :integer
    field :language, :string
    field :source_count, :integer
    field :status, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
