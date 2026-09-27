defmodule Chatwooter.ConfigurationRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.ConfigurationParityFixture

  test "seven restored configuration rows retain IDs, JSON, dates, enums and defaults" do
    ConfigurationParityFixture.insert!(Repo)
    assert length(ConfigurationParityFixture.rows()) == 7

    for {schema, attrs, defaults} <- ConfigurationParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "bot secrets and configuration values are excluded from struct inspection" do
    ConfigurationParityFixture.insert!(Repo)
    bot = Repo.get!(Chatwooter.Automations.AgentBot, 73_001)
    config = Repo.get!(Chatwooter.Platform.InstallationConfig, 73_005)
    refute inspect(bot) =~ bot.secret
    refute inspect(config) =~ "synthetic-password"
  end

  test "email template scopes allow the same name in installation, account and inbox" do
    created = ~N[2026-09-24 10:30:00.123456]

    for {id, account_id, inbox_id} <- [
          {83_001, nil, nil},
          {83_002, 7001, nil},
          {83_003, 7001, 7003},
          {83_004, 7002, nil},
          {83_005, 7001, 7004}
        ] do
      Repo.query!(
        "INSERT INTO email_templates (id, name, body, account_id, inbox_id, created_at, updated_at) VALUES ($1, 'welcome', 'hello', $2, $3, $4, $4)",
        [id, account_id, inbox_id, created]
      )

      assert %{template_type: 1, locale: 0} = Repo.get!(Chatwooter.Platform.EmailTemplate, id)
    end
  end

  for {scope, account_id, inbox_id} <- [
        {:installation, nil, nil},
        {:account, 7001, nil},
        {:inbox, 7001, 7003}
      ] do
    test "email template #{scope} scope rejects duplicate names" do
      params = [unquote(account_id), unquote(inbox_id)]

      sql =
        "INSERT INTO email_templates (name, body, account_id, inbox_id, created_at, updated_at) VALUES ('welcome', 'hello', $1, $2, now(), now())"

      Repo.query!(sql, params)

      assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
               Repo.query(sql, params)
    end
  end

  test "rollup identity is unique" do
    ConfigurationParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO reporting_events_rollups (account_id, date, dimension_type, dimension_id, metric, created_at, updated_at) VALUES (7001, '2026-09-24', 'Inbox', 7003, 'first_response', now(), now())"
             )
  end

  test "one pending execution exists per rule, conversation and episode" do
    ConfigurationParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO automation_rule_pending_executions (automation_rule_id, conversation_id, account_id, due_at, episode_key, created_at, updated_at) VALUES (71014, 7004, 7001, now(), 'fixture-episode', now(), now())"
             )
  end
end
