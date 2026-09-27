defmodule Chatwooter.CaptainAssistantParityFixture do
  @moduledoc false
  @created ~N[2026-09-24 10:30:00.123456]

  def embedding, do: Pgvector.new(List.duplicate(0.5, 1536))

  def embedding_text, do: "[" <> Enum.map_join(1..1536, ",", fn _ -> "0.5" end) <> "]"

  def rows do
    [
      {Chatwooter.Captain.Assistant,
       %{
         id: 131_001,
         name: "Fixture assistant",
         account_id: 7301,
         description: "Restored description",
         config: %{"model" => "fixture"},
         response_guidelines: [%{"rule" => "one"}],
         guardrails: [%{"rule" => "two"}],
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Captain.Inbox,
       %{
         id: 131_002,
         captain_assistant_id: 131_001,
         inbox_id: 7303,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Captain.Document,
       %{
         id: 131_003,
         name: "Fixture document",
         external_link: "https://example.test/fixture-doc",
         content: "Restored content",
         assistant_id: 131_001,
         account_id: 7301,
         status: 2,
         metadata: %{"source" => "dump"},
         sync_status: 1,
         last_synced_at: @created,
         last_sync_attempted_at: @created,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Captain.Scenario,
       %{
         id: 131_004,
         title: "Fixture scenario",
         description: "Restored description",
         instruction: "Restored instruction",
         tools: [%{"tool" => "one"}],
         enabled: false,
         assistant_id: 131_001,
         account_id: 7301,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Captain.CustomTool,
       %{
         id: 131_005,
         account_id: 7301,
         slug: "fixture-tool",
         title: "Fixture tool",
         description: "Restored description",
         http_method: "POST",
         endpoint_url: "https://example.test/tool",
         request_template: "Restored request",
         response_template: "Restored response",
         auth_type: "bearer",
         auth_config: %{"token" => "synthetic-tool-token"},
         param_schema: [%{"param" => "one"}],
         enabled: false,
         assistant_id: 131_001,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Captain.AssistantResponse,
       %{
         id: 131_006,
         question: "Fixture question",
         answer: "Restored answer",
         embedding: embedding(),
         assistant_id: 131_001,
         documentable_id: 131_003,
         account_id: 7301,
         status: 2,
         documentable_type: "Captain::Document",
         edited: true,
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
