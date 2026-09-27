defmodule Chatwooter.CoreConversationSchemaParityTest do
  use Chatwooter.DataCase, async: true

  test "core conversation tables match the upstream physical contract" do
    report = Chatwooter.SchemaParity.compare(Repo, "chatwoot/db/schema.rb")

    for name <- ~w(conversations messages attachments) do
      table = report.tables[name]
      assert table.primary_key.status == :equal, name
      assert table.local_columns == [], name
      assert table.missing_columns == [], name

      for kind <- [:columns, :indexes, :foreign_keys, :checks],
          {key, diff} <- Map.fetch!(table, kind) do
        assert diff.status == :equal, "#{name}.#{kind}.#{key}: #{inspect(diff)}"
      end
    end
  end
end
