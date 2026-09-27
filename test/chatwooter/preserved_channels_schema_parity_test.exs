defmodule Chatwooter.PreservedChannelsSchemaParityTest do
  use Chatwooter.DataCase, async: true

  @tables ~w(channel_api channel_email channel_facebook_pages channel_instagram channel_line channel_sms)

  test "six inactive channel tables preserve their upstream physical contract" do
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
