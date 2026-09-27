defmodule Chatwooter.CaptainAssistantSchemaParityTest do
  use Chatwooter.DataCase, async: true

  @tables ~w(captain_assistants captain_inboxes captain_documents captain_scenarios captain_custom_tools captain_assistant_responses)

  test "captain assistant tables preserve their upstream physical contract" do
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
