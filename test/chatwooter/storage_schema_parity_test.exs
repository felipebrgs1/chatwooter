defmodule Chatwooter.StorageSchemaParityTest do
  use Chatwooter.DataCase, async: true

  @tables ~w(active_storage_blobs active_storage_attachments active_storage_variant_records action_mailbox_inbound_emails audits)

  test "five storage and audit tables match the upstream physical contract" do
    report = Chatwooter.SchemaParity.compare(Repo, "chatwoot/db/schema.rb")

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
end
