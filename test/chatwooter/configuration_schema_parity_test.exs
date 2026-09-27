defmodule Chatwooter.ConfigurationSchemaParityTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.SchemaParity

  @tables ~w(agent_bots agent_bot_inboxes automation_rule_pending_executions
             email_templates installation_configs platform_banners reporting_events_rollups)

  test "seven automation and configuration tables match the upstream physical contract" do
    report = SchemaParity.compare(Repo, "chatwoot/db/schema.rb")
    assert length(@tables) == 7

    for name <- @tables do
      table = report.tables[name]
      assert table.status == :present, name
      assert table.primary_key.status == :equal, name
      assert table.missing_columns == [], name
      assert table.local_columns == [], name

      for kind <- [:columns, :indexes, :foreign_keys, :checks],
          {key, diff} <- Map.fetch!(table, kind) do
        assert diff.status == :equal, "#{name}.#{kind}.#{key}: #{inspect(diff)}"
      end
    end
  end

  test "partial-index predicate changes remain visible in the comparison" do
    path =
      Path.join(System.tmp_dir!(), "email-predicate-#{System.unique_integer([:positive])}.rb")

    source = File.read!("chatwoot/db/schema.rb")

    File.write!(
      path,
      String.replace(
        source,
        "(account_id IS NOT NULL) AND (inbox_id IS NULL)",
        "(account_id IS NOT NULL) OR (inbox_id IS NULL)"
      )
    )

    on_exit(fn -> File.rm(path) end)
    report = SchemaParity.compare(Repo, path)

    assert report.tables["email_templates"].indexes["index_email_templates_on_account_scope"].status ==
             :different
  end
end
