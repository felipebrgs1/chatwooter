defmodule Chatwooter.MonitorParityFixture do
  @moduledoc false
  @created ~N[2026-09-24 10:30:00.123456]
  @plain ~N[2026-09-24 10:30:00]

  def rows do
    [
      {Chatwooter.Conversations.Monitor,
       %{
         id: 133_001,
         account_id: 7301,
         user_id: 7302,
         name: "Fixture monitor",
         condition: "Restored condition",
         model: "fixture-model",
         threshold: 0.75,
         history_since: @created,
         paused_at: @created,
         resumed_at: @created,
         deleted_at: @created,
         data_revision: 3,
         collection_version: 4,
         recheck_requested_at: @created,
         icon: "alert-line",
         icon_color: "#EF4444",
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Conversations.MonitorEvaluation,
       %{
         id: 133_002,
         account_id: 7301,
         monitor_id: 133_001,
         conversation_id: 133_010,
         status: "matched",
         input_revision: 2,
         generation: 3,
         requested_version: 4,
         score: 0.9,
         model: "fixture-model",
         error_code: "E1",
         matched_at: @created,
         evaluated_at: @created,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Conversations.MonitorScan,
       %{
         id: 133_003,
         monitor_id: 133_001,
         kind: "initial",
         collection_version: 4,
         started_at: @created,
         ended_at: @created,
         cursor: 42,
         enumerated_at: @created,
         cancelled_at: @created,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Conversations.MonitorWorkItem,
       %{
         id: 133_004,
         account_id: 7301,
         conversation_id: 133_010,
         revision: 2,
         processed_revision: 1,
         full_history_revision: 3,
         generation: 1,
         due_at: @created,
         lease_token: "fixture-lease",
         lease_expires_at: @created,
         attempts: 2,
         error_code: "E2",
         requested_at: @created,
         activity_at: @created,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Conversations.MonitorDailyUsage,
       %{
         id: 133_005,
         account_id: 7301,
         usage_date: ~D[2026-09-24],
         calls_count: 9,
         limit_reached_at: @created,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Conversations.Call,
       %{
         id: 133_006,
         account_id: 7301,
         inbox_id: 7303,
         conversation_id: 133_010,
         contact_id: 7304,
         message_id: 133_011,
         accepted_by_agent_id: 7302,
         provider_call_id: "fixture-provider-call",
         provider: 1,
         direction: 2,
         status: "completed",
         started_at: @created,
         duration_seconds: 120,
         end_reason: "hangup",
         meta: %{"source" => "dump"},
         transcript: "Restored transcript",
         created_at: @created,
         updated_at: @created
       }, %{}}
    ]
  end

  def insert!(repo) do
    repo.query!(
      "INSERT INTO accounts (id, name, created_at, updated_at) VALUES (7301, 'Monitor fixture', $1, $1) ON CONFLICT (id) DO NOTHING",
      [@plain]
    )

    repo.query!(
      "INSERT INTO users (id, name, created_at, updated_at) VALUES (7302, 'Monitor fixture', $1, $1) ON CONFLICT (id) DO NOTHING",
      [@plain]
    )

    repo.query!(
      "INSERT INTO inboxes (id, channel_id, account_id, name, created_at, updated_at) VALUES (7303, 1, 7301, 'Monitor fixture', $1, $1) ON CONFLICT (id) DO NOTHING",
      [@plain]
    )

    repo.query!(
      "INSERT INTO contacts (id, account_id, created_at, updated_at) VALUES (7304, 7301, $1, $1) ON CONFLICT (id) DO NOTHING",
      [@plain]
    )

    repo.query!(
      "INSERT INTO conversations (id, account_id, inbox_id, display_id, created_at, updated_at) VALUES (133010, 7301, 7303, 11, $1, $1) ON CONFLICT (id) DO NOTHING",
      [@plain]
    )

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
