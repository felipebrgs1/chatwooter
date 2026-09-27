defmodule Chatwooter.SchemaParityTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.SchemaParity
  alias Chatwooter.SchemaParity.Snapshot
  alias Mix.Tasks.Chatwooter.SchemaDiff

  @schema Path.expand("../../chatwoot/db/schema.rb", __DIR__)

  test "catalogs all upstream tables, columns, indexes, foreign keys and extensions" do
    snapshot = Snapshot.load!(@schema)

    assert snapshot.tables["labels"].columns["title"].type == "character varying"

    assert Jason.decode!(snapshot.tables["webhooks"].columns["subscriptions"].default) ==
             ~w(conversation_status_changed conversation_updated conversation_created contact_created contact_updated message_created message_updated webwidget_triggered)

    assert snapshot.tables["custom_roles"].columns["permissions"].type == "text[]"

    assert Jason.decode!(snapshot.tables["portals"].columns["config"].default) == %{
             "allowed_locales" => ["en"]
           }

    assert snapshot.tables["reporting_events_rollups"].columns["sum_value"].default == "0.0"
    assert snapshot.version == "2026_09_24_000000"
    assert map_size(snapshot.tables) == 103
    assert "vector" in snapshot.extensions
    assert snapshot.tables["accounts"].primary_key == "integer"
    assert snapshot.tables["conversations"].columns["display_id"].nullable == false
    assert snapshot.tables["conversations"].columns["uuid"].default == "gen_random_uuid()"
    assert snapshot.tables["messages"].columns["content_attributes"].type == "json"
    assert snapshot.tables["messages"].columns["created_at"].precision == nil
    assert snapshot.tables["contacts"].indexes["index_contacts_on_nonempty_fields"].where != nil
    assert snapshot.tables["inboxes"].foreign_keys["portal_id"].table == "portals"
    assert snapshot.tables["portals_members"].primary_key == nil

    assert snapshot.tables["conversation_monitor_daily_usages"].checks[
             "monitor_daily_usage_nonnegative"
           ] == "calls_count >= 0"

    assert snapshot.tables["campaign_recipients"].foreign_keys["inbox_id"] == %{
             table: "inboxes",
             on_delete: "cascade"
           }

    assert snapshot.triggers["accounts_after_insert_row_tr"] == "accounts"
    assert Enum.all?(snapshot.tables, fn {_name, table} -> map_size(table.columns) > 0 end)
  end

  test "rejects unrecognized schema instructions instead of reporting false parity" do
    path = Path.join(System.tmp_dir!(), "schema-parity-#{System.unique_integer([:positive])}.rb")

    File.write!(
      path,
      "ActiveRecord::Schema[7.1].define(version: 2026_09_24_000000) do\n  create_table \"a\" do |t|\n    t.magic \"x\"\n  end\nend\n"
    )

    on_exit(fn -> File.rm(path) end)

    assert_raise ArgumentError, ~r/unsupported schema instruction.*t.magic/s, fn ->
      Snapshot.load!(path)
    end
  end

  test "schema diff keeps the versioned initial baseline immutable" do
    baseline = Path.expand("../../docs/schema_parity_baseline.json", __DIR__)

    alias_path =
      Path.join(System.tmp_dir!(), "schema-baseline-#{System.unique_integer([:positive])}.json")

    relative_alias =
      Path.expand(
        "../../docs/.schema-parity-test-link-#{System.unique_integer([:positive])}.json",
        __DIR__
      )

    File.ln_s!(baseline, alias_path)
    File.ln_s!("schema_parity_baseline.json", relative_alias)

    on_exit(fn ->
      File.rm(alias_path)
      File.rm(relative_alias)
    end)

    for path <- [baseline, "docs/schema_parity_baseline.json", alias_path, relative_alias] do
      assert_raise Mix.Error, ~r/baseline congelado/, fn ->
        SchemaDiff.output_path!(path)
      end
    end

    assert SchemaDiff.output_path!("/tmp/chatwooter-current.json") ==
             "/tmp/chatwooter-current.json"

    assert_raise Mix.Error, ~r/baseline congelado/, fn ->
      SchemaDiff.run(["--json", "docs/schema_parity_baseline.json"])
    end
  end

  test "all present upstream tables match the migrated physical contract" do
    report = SchemaParity.compare(Repo, @schema)
    assert report.summary.upstream_tables == 103
    assert report.summary.compared_tables == 103
    assert report.summary.missing_tables == 0
    assert "users_tokens" in report.local_tables
    refute report.summary.parity?
    assert report.missing_tables == []

    for extension <- ~w(pgcrypto pg_stat_statements pg_trgm vector) do
      assert report.extensions[extension].status == :equal, extension
    end

    assert Enum.all?(report.extensions, fn {_, diff} -> diff.status == :equal end),
           inspect(report.extensions)

    for {name, table} <- report.tables, table.status == :present do
      assert table.primary_key.status == :equal, name
      assert table.missing_columns == [], name
      assert table.local_columns == [], name

      for kind <- [:columns, :indexes, :foreign_keys, :checks],
          {key, diff} <- Map.fetch!(table, kind) do
        assert diff.status == :equal, "#{name}.#{kind}.#{key}: #{inspect(diff)}"
      end
    end
  end

  test "detects altered physical defaults and missing indexes" do
    Repo.query!("ALTER TABLE contacts ALTER COLUMN blocked SET DEFAULT true")
    Repo.query!("DROP INDEX index_contacts_on_blocked")
    report = SchemaParity.compare(Repo, @schema)
    assert report.tables["contacts"].columns["blocked"].status == :different
    assert report.tables["contacts"].indexes["index_contacts_on_blocked"].status == :missing

    # Presence is proven; bodies are not verifiable from the catalog.
    for name <-
          ~w(accounts_after_insert_row_tr conversations_before_insert_row_tr camp_dpid_before_insert) do
      assert report.triggers[name].status == :body_unverified, name
    end

    assert report.triggers["campaigns_before_insert_row_tr"].status == :body_unverified
  end

  test "compares check bodies rather than only their names" do
    report = SchemaParity.compare(Repo, @schema)

    assert report.tables["conversation_monitor_daily_usages"].checks[
             "monitor_daily_usage_nonnegative"
           ].status == :equal

    Repo.query!(
      "ALTER TABLE conversation_monitor_daily_usages DROP CONSTRAINT monitor_daily_usage_nonnegative"
    )

    Repo.query!("""
    ALTER TABLE conversation_monitor_daily_usages
    ADD CONSTRAINT monitor_daily_usage_nonnegative CHECK (calls_count >= -1)
    """)

    changed = SchemaParity.compare(Repo, @schema)

    assert changed.tables["conversation_monitor_daily_usages"].checks[
             "monitor_daily_usage_nonnegative"
           ].status == :different
  end

  test "compares sort direction and null placement for the correct index column" do
    Repo.query!("DROP INDEX index_contacts_on_account_id_and_last_activity_at")

    Repo.query!("""
    CREATE INDEX index_contacts_on_account_id_and_last_activity_at
    ON contacts (account_id DESC NULLS LAST, last_activity_at ASC NULLS LAST)
    """)

    report = SchemaParity.compare(Repo, @schema)
    index = report.tables["contacts"].indexes["index_contacts_on_account_id_and_last_activity_at"]
    assert index.status == :different
    assert index.actual.orders == ["DESC NULLS LAST", "ASC NULLS LAST"]
  end

  test "requires the declared operator class on every indexed column" do
    Repo.query!("CREATE TABLE parity_index_probe (first varchar, second varchar)")

    Repo.query!("""
    CREATE INDEX parity_index_probe_idx ON parity_index_probe
      (first text_pattern_ops, second text_ops)
    """)

    path = Path.join(System.tmp_dir!(), "index-parity-#{System.unique_integer([:positive])}.rb")

    File.write!(path, """
    ActiveRecord::Schema[7.1].define(version: 1) do
      create_table "parity_index_probe", id: false do |t|
        t.string "first"
        t.string "second"
        t.index ["first", "second"], name: "parity_index_probe_idx", opclass: :text_pattern_ops
      end
    end
    """)

    on_exit(fn -> File.rm(path) end)
    report = SchemaParity.compare(Repo, path)

    assert report.tables["parity_index_probe"].indexes["parity_index_probe_idx"].status ==
             :different
  end
end
