defmodule Chatwooter.CapacitySchemaParityTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.SchemaParity

  @tables ~w(account_saml_settings agent_capacity_policies assignment_policies
             inbox_assignment_policies inbox_capacity_limits leaves folders)

  test "seven account and capacity tables match the upstream physical contract" do
    report = SchemaParity.compare(Repo, "chatwoot/db/schema.rb")
    assert length(@tables) == 7

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
