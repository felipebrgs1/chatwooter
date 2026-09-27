defmodule Chatwooter.SchemaParityTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.SchemaParity
  alias Chatwooter.SchemaParity.Snapshot

  @schema Path.expand("../../chatwoot/db/schema.rb", __DIR__)

  test "catalogs all upstream tables, columns, indexes, foreign keys and extensions" do
    snapshot = Snapshot.load!(@schema)

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

  test "compares five critical tables against migrated PostgreSQL, including mismatched types and defaults" do
    report = SchemaParity.compare(Repo, @schema)
    assert report.summary.upstream_tables == 103
    assert "channel_whatsapp" in report.missing_tables
    assert map_size(report.tables) == 103
    assert report.tables["teams"].status == :present
    assert report.tables["teams"].columns["name"].status == :equal
    assert "users_tokens" in report.local_tables
    assert "display_id" in report.tables["conversations"].missing_columns
    assert report.tables["conversations"].columns["status"].expected.type == "integer"

    assert report.tables["conversations"].columns["status"].actual.type ==
             "character varying(255)"

    assert "content_attributes" in report.tables["messages"].missing_columns
    assert "channel_id" in report.tables["inboxes"].missing_columns
    assert "identifier" in report.tables["contacts"].missing_columns
    assert "support_email" in report.tables["accounts"].missing_columns
    refute report.summary.parity?
  end

  test "detects constraints and indexes from the physical database, not Ecto structs" do
    report = SchemaParity.compare(Repo, @schema)

    assert report.tables["contacts"].indexes["contacts_account_id_phone_number_index"].status ==
             :local_only

    assert report.tables["conversations"].indexes[
             "index_conversations_on_account_id_and_display_id"
           ].status == :missing

    assert report.tables["inboxes"].foreign_keys["account_id"].status == :local_only
    assert report.tables["inboxes"].columns["account_id"].status == :different
    assert report.tables["accounts"].columns["name"].status == :equal
    assert report.triggers["conversations_before_insert_row_tr"].status == :missing
  end
end
