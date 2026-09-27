defmodule Chatwooter.CoreInboxSchemaParityTest do
  use Chatwooter.DataCase, async: true
  alias Chatwooter.SchemaParity

  test "inboxes and memberships match the upstream physical contract" do
    report = SchemaParity.compare(Repo, "chatwoot/db/schema.rb")

    for name <- ~w(inboxes inbox_members teams team_members) do
      table = report.tables[name]
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
