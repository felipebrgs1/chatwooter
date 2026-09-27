defmodule Chatwooter.PlatformSchemaParityTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.SchemaParity

  @tables ~w(access_tokens webhooks notifications notification_settings notification_subscriptions
             tags taggings conversation_participants csat_survey_responses custom_filters custom_roles
             dashboard_apps integrations_hooks automation_rules macros mentions reporting_events
             sla_policies applied_slas sla_events)

  test "twenty additional tables match upstream columns, defaults, keys and indexes" do
    report = SchemaParity.compare(Repo, "chatwoot/db/schema.rb")
    assert length(@tables) == 20

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

  test "comparison rejects changed subscription defaults and a different operator class" do
    path =
      Path.join(System.tmp_dir!(), "parity-contract-#{System.unique_integer([:positive])}.rb")

    source = File.read!("chatwoot/db/schema.rb")

    changed =
      source
      |> String.replace("conversation_status_changed", "wrong_event")
      |> String.replace("gin_trgm_ops", "gist_trgm_ops")

    File.write!(path, changed)
    on_exit(fn -> File.rm(path) end)
    report = SchemaParity.compare(Repo, path)
    assert report.tables["webhooks"].columns["subscriptions"].status == :different
    assert report.tables["tags"].indexes["tags_name_trgm_idx"].status == :different
  end

  test "the tags search index uses the trigram operator class" do
    assert [["gin", "gin_trgm_ops"]] =
             Repo.query!("""
             SELECT am.amname, opc.opcname
             FROM pg_index i
             JOIN pg_class c ON c.oid = i.indexrelid
             JOIN pg_namespace n ON n.oid = c.relnamespace
             JOIN pg_am am ON am.oid = c.relam
             JOIN pg_opclass opc ON opc.oid = i.indclass[0]
             WHERE n.nspname = current_schema() AND c.relname = 'tags_name_trgm_idx'
             """).rows
  end
end
