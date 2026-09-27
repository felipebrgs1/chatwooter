defmodule Chatwooter.Conversations.CsatSurveyResponse do
  @moduledoc "Read mapping of upstream csat_survey_responses; stored enum integers are preserved."
  use Ecto.Schema

  schema "csat_survey_responses" do
    field :account_id, :integer
    field :conversation_id, :integer
    field :message_id, :integer
    field :rating, :integer
    field :feedback_message, :string
    field :contact_id, :integer
    field :assigned_agent_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :csat_review_notes, :string
    field :review_notes_updated_at, :naive_datetime_usec
    field :review_notes_updated_by_id, :integer
  end
end
