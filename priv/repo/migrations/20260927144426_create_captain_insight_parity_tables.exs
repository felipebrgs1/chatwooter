defmodule Chatwooter.Repo.Migrations.CreateCaptainInsightParityTables do
  use Ecto.Migration

  def change do
    create table(:captain_faq_suggestions) do
      add :question, :varchar, null: false
      add :answer, :text, null: false
      add :embedding, :"vector(1536)"
      add :assistant_id, :bigint, null: false
      add :account_id, :bigint, null: false
      add :language, :varchar, default: "en", null: false
      add :source_count, :integer, default: 0, null: false
      add :status, :integer, default: 0, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:captain_faq_suggestions, [:account_id],
             name: :index_captain_faq_suggestions_on_account_id
           )

    create index(:captain_faq_suggestions, [:account_id, :assistant_id, :status, :language],
             name: :idx_cap_faq_suggestions_on_account_assistant_status_language
           )

    create index(:captain_faq_suggestions, [:assistant_id],
             name: :index_captain_faq_suggestions_on_assistant_id
           )

    create index(:captain_faq_suggestions, ["embedding vector_cosine_ops"],
             name: :vector_idx_captain_faq_suggestions_embedding,
             using: :ivfflat
           )

    create table(:captain_faq_observations) do
      add :account_id, :bigint, null: false
      add :conversation_id, :bigint, null: false
      add :faq_suggestion_id, :bigint
      add :generated_question, :varchar, null: false
      add :generated_answer, :text, null: false
      add :language, :varchar, default: "en", null: false
      add :status, :integer, default: 0, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:captain_faq_observations, [:account_id],
             name: :index_captain_faq_observations_on_account_id
           )

    create unique_index(:captain_faq_observations, [:conversation_id, :faq_suggestion_id],
             name: :idx_captain_faq_observations_on_conversation_and_suggestion,
             where: "(faq_suggestion_id IS NOT NULL)"
           )

    create index(:captain_faq_observations, [:conversation_id],
             name: :index_captain_faq_observations_on_conversation_id
           )

    create index(:captain_faq_observations, [:faq_suggestion_id],
             name: :index_captain_faq_observations_on_faq_suggestion_id
           )

    create table(:captain_message_reports) do
      add :account_id, :bigint, null: false
      add :conversation_id, :bigint, null: false
      add :message_id, :bigint, null: false
      add :user_id, :bigint, null: false
      add :report_reason, :varchar, null: false
      add :description, :text
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:captain_message_reports, [:account_id],
             name: :index_captain_message_reports_on_account_id
           )

    create index(:captain_message_reports, [:conversation_id],
             name: :index_captain_message_reports_on_conversation_id
           )

    create index(:captain_message_reports, [:message_id],
             name: :index_captain_message_reports_on_message_id
           )

    create index(:captain_message_reports, [:user_id],
             name: :index_captain_message_reports_on_user_id
           )

    create table(:agent_sessions) do
      add :session_type, :integer, null: false
      add :subject_type, :varchar, null: false
      add :subject_id, :bigint, null: false
      add :result_type, :varchar
      add :result_id, :bigint
      add :account_id, :bigint, null: false
      add :assistant_id, :bigint, null: false
      add :user_id, :bigint
      add :llm_model, :varchar
      add :credits_consumed, :float
      add :faq_ids, :jsonb, default: fragment("'[]'::jsonb")
      add :document_ids, :jsonb, default: fragment("'[]'::jsonb")
      add :scenario_ids, :jsonb, default: fragment("'[]'::jsonb")
      add :run_context, :jsonb, default: fragment("'{}'::jsonb")
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :cited_document_ids, :jsonb, default: fragment("'[]'::jsonb"), null: false
      add :used_faq_ids, :jsonb, default: fragment("'[]'::jsonb"), null: false
    end

    create index(:agent_sessions, [:account_id, :result_type, :result_id],
             name: :idx_on_account_id_result_type_result_id_ca66c00cd7
           )

    create index(:agent_sessions, [:account_id, :session_type, :created_at],
             name: :idx_on_account_id_session_type_created_at_c20a14bd4e
           )

    create index(:agent_sessions, [:account_id, :subject_type, :subject_id],
             name: :idx_on_account_id_subject_type_subject_id_6d60963b3d
           )

    create index(:agent_sessions, [:account_id], name: :index_agent_sessions_on_account_id)

    create index(:agent_sessions, [:assistant_id], name: :index_agent_sessions_on_assistant_id)

    create index(:agent_sessions, [:cited_document_ids],
             name: :index_agent_sessions_on_cited_document_ids,
             using: :gin
           )

    create index(:agent_sessions, [:document_ids],
             name: :index_agent_sessions_on_document_ids,
             using: :gin
           )

    create index(:agent_sessions, [:used_faq_ids],
             name: :index_agent_sessions_on_used_faq_ids,
             using: :gin
           )

    create index(:agent_sessions, [:user_id], name: :index_agent_sessions_on_user_id)

    create table(:conversation_outcomes) do
      add :account_id, :bigint, null: false
      add :assistant_id, :bigint, null: false
      add :conversation_id, :bigint, null: false
      add :inbox_id, :bigint, null: false
      add :first_captain_reply_at, :"timestamp(6)"
      add :last_captain_reply_at, :"timestamp(6)"
      add :captain_reply_count, :integer, default: 0, null: false
      add :first_human_reply_at, :"timestamp(6)"
      add :handoff_at, :"timestamp(6)"
      add :handoff_reason_category, :varchar
      add :resolved_at, :"timestamp(6)"
      add :csat_rating, :integer
      add :csat_received_at, :"timestamp(6)"
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :episode_trigger, :varchar, default: "initial", null: false
      add :started_at, :"timestamp(6)", null: false
      add :ended_at, :"timestamp(6)"
    end

    create index(:conversation_outcomes, [:account_id, :assistant_id, :handoff_at],
             name: :idx_conversation_outcomes_on_assistant_handoff_at
           )

    create index(:conversation_outcomes, [:account_id, :assistant_id, :resolved_at],
             name: :idx_conversation_outcomes_on_assistant_resolved_at
           )

    create index(:conversation_outcomes, [:account_id, :assistant_id, :started_at],
             name: :idx_conversation_outcomes_on_assistant_started_at
           )

    create unique_index(:conversation_outcomes, [:account_id, :conversation_id, :started_at],
             name: :idx_conversation_outcomes_unique_boundary
           )

    create unique_index(:conversation_outcomes, [:account_id, :conversation_id],
             name: :idx_conversation_outcomes_initial_episode,
             where: "((episode_trigger)::text = 'initial'::text)"
           )

    create unique_index(:conversation_outcomes, [:account_id, :conversation_id],
             name: :idx_conversation_outcomes_open_episode,
             where: "(ended_at IS NULL)"
           )

    create index(:conversation_outcomes, [:account_id],
             name: :index_conversation_outcomes_on_account_id
           )

    create index(:conversation_outcomes, [:assistant_id],
             name: :index_conversation_outcomes_on_assistant_id
           )

    create index(:conversation_outcomes, [:conversation_id],
             name: :index_conversation_outcomes_on_conversation_id
           )

    create index(:conversation_outcomes, [:inbox_id],
             name: :index_conversation_outcomes_on_inbox_id
           )
  end
end
