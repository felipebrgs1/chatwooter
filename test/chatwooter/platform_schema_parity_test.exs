defmodule Chatwooter.PlatformSchemaParityTest do
  use Chatwooter.DataCase, async: true

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
