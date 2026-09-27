defmodule Chatwooter.Repo.Migrations.CreateCaptainAssistantParityTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS vector", "SELECT 1"

    create table(:captain_assistants) do
      add :name, :varchar, null: false
      add :account_id, :bigint, null: false
      add :description, :text
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :config, :jsonb, default: fragment("'{}'::jsonb"), null: false
      add :response_guidelines, :jsonb, default: fragment("'[]'::jsonb")
      add :guardrails, :jsonb, default: fragment("'[]'::jsonb")
    end

    create index(:captain_assistants, [:account_id],
             name: :index_captain_assistants_on_account_id
           )

    create table(:captain_inboxes) do
      add :captain_assistant_id, :bigint, null: false
      add :inbox_id, :bigint, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create unique_index(:captain_inboxes, [:captain_assistant_id, :inbox_id],
             name: :index_captain_inboxes_on_captain_assistant_id_and_inbox_id
           )

    create index(:captain_inboxes, [:captain_assistant_id],
             name: :index_captain_inboxes_on_captain_assistant_id
           )

    create index(:captain_inboxes, [:inbox_id], name: :index_captain_inboxes_on_inbox_id)

    create table(:captain_documents) do
      add :name, :varchar
      add :external_link, :text, null: false
      add :content, :text
      add :assistant_id, :bigint, null: false
      add :account_id, :bigint, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :status, :integer, default: 0, null: false
      add :metadata, :jsonb, default: fragment("'{}'::jsonb")
      add :sync_status, :integer
      add :last_synced_at, :"timestamp(6)"
      add :last_sync_attempted_at, :"timestamp(6)"
    end

    create unique_index(:captain_documents, ["assistant_id", "md5(external_link)"],
             name: :idx_captain_documents_on_assistant_id_and_external_link_md5
           )

    create index(:captain_documents, [:account_id, :assistant_id, :sync_status, :last_synced_at],
             name: :idx_captain_documents_on_account_assistant_sync_stats
           )

    create index(:captain_documents, [:account_id, :sync_status],
             name: :index_captain_documents_on_account_id_and_sync_status
           )

    create index(:captain_documents, [:account_id], name: :index_captain_documents_on_account_id)

    create index(:captain_documents, [:assistant_id],
             name: :index_captain_documents_on_assistant_id
           )

    create index(:captain_documents, [:status], name: :index_captain_documents_on_status)

    create table(:captain_scenarios) do
      add :title, :varchar
      add :description, :text
      add :instruction, :text
      add :tools, :jsonb, default: fragment("'[]'::jsonb")
      add :enabled, :boolean, default: true, null: false
      add :assistant_id, :bigint, null: false
      add :account_id, :bigint, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:captain_scenarios, [:account_id], name: :index_captain_scenarios_on_account_id)

    create index(:captain_scenarios, [:assistant_id, :enabled],
             name: :index_captain_scenarios_on_assistant_id_and_enabled
           )

    create index(:captain_scenarios, [:assistant_id],
             name: :index_captain_scenarios_on_assistant_id
           )

    create index(:captain_scenarios, [:enabled], name: :index_captain_scenarios_on_enabled)

    create table(:captain_custom_tools) do
      add :account_id, :bigint, null: false
      add :slug, :varchar, null: false
      add :title, :varchar, null: false
      add :description, :text
      add :http_method, :varchar, default: "GET", null: false
      add :endpoint_url, :text, null: false
      add :request_template, :text
      add :response_template, :text
      add :auth_type, :varchar, default: "none"
      add :auth_config, :jsonb, default: fragment("'{}'::jsonb")
      add :param_schema, :jsonb, default: fragment("'[]'::jsonb")
      add :enabled, :boolean, default: true, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :assistant_id, :bigint
    end

    create index(:captain_custom_tools, [:account_id],
             name: :index_captain_custom_tools_on_account_id
           )

    create unique_index(:captain_custom_tools, [:assistant_id, :slug],
             name: :index_captain_custom_tools_on_assistant_id_and_slug
           )

    create table(:captain_assistant_responses) do
      add :question, :varchar, null: false
      add :answer, :text, null: false
      add :embedding, :"vector(1536)"
      add :assistant_id, :bigint, null: false
      add :documentable_id, :bigint
      add :account_id, :bigint, null: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :status, :integer, default: 1, null: false
      add :documentable_type, :varchar
      add :edited, :boolean, default: false, null: false
    end

    create index(:captain_assistant_responses, [:account_id],
             name: :index_captain_assistant_responses_on_account_id
           )

    create index(:captain_assistant_responses, [:assistant_id],
             name: :index_captain_assistant_responses_on_assistant_id
           )

    create index(:captain_assistant_responses, [:documentable_id, :documentable_type],
             name: :idx_cap_asst_resp_on_documentable
           )

    create index(:captain_assistant_responses, [:embedding],
             name: :vector_idx_knowledge_entries_embedding,
             using: :ivfflat
           )

    create index(:captain_assistant_responses, [:status],
             name: :index_captain_assistant_responses_on_status
           )
  end
end
