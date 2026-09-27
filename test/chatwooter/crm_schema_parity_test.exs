defmodule Chatwooter.CrmSchemaParityTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.SchemaParity

  @tables ~w(labels notes canned_responses custom_attribute_definitions working_hours)

  test "CRM tables match the physical upstream contract" do
    report = SchemaParity.compare(Repo, "chatwoot/db/schema.rb")

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
