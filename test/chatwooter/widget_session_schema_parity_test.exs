defmodule Chatwooter.WidgetSessionSchemaParityTest do
  use Chatwooter.DataCase, async: true
  alias Chatwooter.SchemaParity

  test "web widget and session tables match the upstream physical contract" do
    report = SchemaParity.compare(Repo, "chatwoot/db/schema.rb")

    for name <- ~w(channel_web_widgets user_sessions) do
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
