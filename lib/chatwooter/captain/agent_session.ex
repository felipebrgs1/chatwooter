defmodule Chatwooter.Captain.AgentSession do
  @moduledoc "Read mapping of upstream agent_sessions; Captain stays out of scope."
  use Ecto.Schema

  schema "agent_sessions" do
    field :session_type, :integer
    field :subject_type, :string
    field :subject_id, :integer
    field :result_type, :string
    field :result_id, :integer
    field :account_id, :integer
    field :assistant_id, :integer
    field :user_id, :integer
    field :llm_model, :string
    field :credits_consumed, :float
    field :faq_ids, Chatwooter.Types.JsonValue
    field :document_ids, Chatwooter.Types.JsonValue
    field :scenario_ids, Chatwooter.Types.JsonValue
    field :run_context, Chatwooter.Types.JsonValue
    field :cited_document_ids, Chatwooter.Types.JsonValue
    field :used_faq_ids, Chatwooter.Types.JsonValue
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
