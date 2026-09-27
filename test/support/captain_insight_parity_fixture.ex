defmodule Chatwooter.CaptainInsightParityFixture do
  @moduledoc false
  @created ~N[2026-09-24 10:30:00.123456]

  def embedding, do: Pgvector.new(List.duplicate(0.5, 1536))

  def embedding_text, do: "[" <> Enum.map_join(1..1536, ",", fn _ -> "0.5" end) <> "]"

  def rows do
    [
      {Chatwooter.Captain.FaqSuggestion,
       %{
         id: 132_001,
         question: "Fixture question",
         answer: "Restored answer",
         embedding: embedding(),
         assistant_id: 131_001,
         account_id: 7301,
         language: "pt",
         source_count: 4,
         status: 2,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Captain.FaqObservation,
       %{
         id: 132_002,
         account_id: 7301,
         conversation_id: 133_010,
         faq_suggestion_id: 132_001,
         generated_question: "Generated question",
         generated_answer: "Generated answer",
         language: "pt",
         status: 1,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Captain.MessageReport,
       %{
         id: 132_003,
         account_id: 7301,
         conversation_id: 133_010,
         message_id: 133_011,
         user_id: 7302,
         report_reason: "incorrect",
         description: "Restored description",
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Captain.AgentSession,
       %{
         id: 132_004,
         session_type: 1,
         subject_type: "Conversation",
         subject_id: 133_010,
         result_type: "Captain::AssistantResponse",
         result_id: 131_006,
         account_id: 7301,
         assistant_id: 131_001,
         user_id: 7302,
         llm_model: "fixture-model",
         credits_consumed: 1.5,
         faq_ids: [132_001],
         document_ids: [131_003],
         scenario_ids: [131_004],
         run_context: %{"turn" => 2},
         cited_document_ids: [131_003],
         used_faq_ids: [132_001],
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Conversations.Outcome,
       %{
         id: 132_005,
         account_id: 7301,
         assistant_id: 131_001,
         conversation_id: 133_010,
         inbox_id: 7303,
         first_captain_reply_at: @created,
         last_captain_reply_at: @created,
         captain_reply_count: 3,
         first_human_reply_at: @created,
         handoff_at: @created,
         handoff_reason_category: "complex",
         resolved_at: @created,
         csat_rating: 5,
         csat_received_at: @created,
         episode_trigger: "handoff",
         started_at: @created,
         ended_at: @created,
         created_at: @created,
         updated_at: @created
       }, %{}}
    ]
  end

  def insert!(repo) do
    for {schema, attrs, _defaults} <- rows() do
      columns = Map.keys(attrs) |> Enum.sort()
      keys = Enum.map_join(columns, ", ", &Atom.to_string/1)
      placeholders = 1..length(columns) |> Enum.map_join(", ", &"$#{&1}")
      values = Enum.map(columns, &Map.fetch!(attrs, &1))
      table = schema.__schema__(:source)
      repo.query!("INSERT INTO #{table} (#{keys}) VALUES (#{placeholders})", values)
    end

    :ok
  end
end
