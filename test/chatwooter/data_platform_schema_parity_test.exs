defmodule Chatwooter.DataPlatformSchemaParityTest do
  use Chatwooter.DataCase, async: true

  @tables ~w(data_imports data_import_items data_import_mappings data_import_errors platform_apps platform_app_permissibles)

  test "six data and platform tables preserve the complete upstream physical contract" do
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
