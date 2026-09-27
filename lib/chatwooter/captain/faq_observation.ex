defmodule Chatwooter.Captain.FaqObservation do
  @moduledoc "Read mapping of upstream captain_faq_observations; Captain stays out of scope."
  use Ecto.Schema

  schema "captain_faq_observations" do
    field :account_id, :integer
    field :conversation_id, :integer
    field :faq_suggestion_id, :integer
    field :generated_question, :string
    field :generated_answer, :string
    field :language, :string
    field :status, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
