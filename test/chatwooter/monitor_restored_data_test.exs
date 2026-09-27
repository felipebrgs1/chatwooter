defmodule Chatwooter.MonitorRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.MonitorParityFixture

  test "restored monitor rows retain IDs, floats, dates, JSON and defaults" do
    MonitorParityFixture.insert!(Repo)

    for {schema, attrs, defaults} <- MonitorParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "omitted monitor revisions, icons and evaluation state retain upstream defaults" do
    MonitorParityFixture.insert!(Repo)
    created = ~N[2026-09-24 10:30:00.123456]

    Repo.query!(
      "INSERT INTO conversation_monitors (id, account_id, name, \"condition\", model, threshold, history_since, created_at, updated_at) VALUES (133011, 7301, 'Defaults', 'cond', 'm', 0.5, $1, $1, $1)",
      [created]
    )

    assert %{
             data_revision: 0,
             collection_version: 0,
             icon: "chat-3-line",
             icon_color: "#3B82F6"
           } = Repo.get!(Chatwooter.Conversations.Monitor, 133_011)

    Repo.query!(
      "INSERT INTO conversations (id, account_id, inbox_id, display_id, created_at, updated_at) VALUES (133013, 7301, 7303, 12, $1, $1)",
      [~N[2026-09-24 10:30:00]]
    )

    Repo.query!(
      "INSERT INTO conversation_monitor_evaluations (id, account_id, monitor_id, conversation_id, created_at, updated_at) VALUES (133012, 7301, 133001, 133013, $1, $1)",
      [created]
    )

    assert %{status: "pending", input_revision: 0, generation: 0} =
             Repo.get!(Chatwooter.Conversations.MonitorEvaluation, 133_012)
  end

  test "daily usage rejects negative call counts" do
    MonitorParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} =
             Repo.query(
               "INSERT INTO conversation_monitor_daily_usages (account_id, usage_date, calls_count, created_at, updated_at) VALUES (7301, '2026-09-25', -1, now(), now())"
             )
  end

  test "evaluation keeps one row per monitor and conversation" do
    MonitorParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO conversation_monitor_evaluations (account_id, monitor_id, conversation_id, created_at, updated_at) VALUES (7301, 133001, 133010, now(), now())"
             )
  end

  test "provider call identity stays unique across calls" do
    MonitorParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO calls (account_id, inbox_id, conversation_id, contact_id, provider_call_id, provider, direction, created_at, updated_at) VALUES (7301, 7303, 133010, 7304, 'fixture-provider-call', 1, 2, now(), now())"
             )
  end
end
