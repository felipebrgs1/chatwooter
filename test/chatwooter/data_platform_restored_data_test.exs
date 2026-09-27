defmodule Chatwooter.DataPlatformRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.DataPlatformParityFixture

  test "raw upstream rows retain IDs, JSON arrays, enums, defaults and microsecond timestamps" do
    DataPlatformParityFixture.insert!(Repo)

    for {schema, attrs, defaults} <- DataPlatformParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "nullable import progress and lifecycle fields load as nil" do
    DataPlatformParityFixture.insert!(Repo)
    record = Repo.get!(Chatwooter.Platform.DataImport, 91_001)

    for field <- [
          :processing_errors,
          :total_records,
          :processed_records,
          :initiated_by_id,
          :access_token,
          :started_at,
          :completed_at,
          :abandoned_at,
          :last_error_at
        ] do
      assert Map.fetch!(record, field) == nil
    end
  end

  test "restored import lifecycle and arbitrary JSON values do not require a workflow" do
    created = ~N[2026-09-24 10:30:00.123456]

    Repo.query!(
      "INSERT INTO data_imports (id, account_id, data_type, status, processing_errors, total_records, processed_records, import_types, initiated_by_id, access_token, source_metadata, stats, cursor, started_at, completed_at, abandoned_at, last_error_at, created_at, updated_at) VALUES (92001, 7001, 'contacts', 8, 'diagnostic', 12, 10, $1, 7002, 'synthetic-secret', $2, $3, $4, $5, $5, $5, $5, $5, $5)",
      [["contacts", "messages"], %{"source" => "dump"}, [10, 12], "opaque-cursor", created]
    )

    record = Repo.get!(Chatwooter.Platform.DataImport, 92_001)
    assert record.status == 8
    assert record.import_types == ["contacts", "messages"]
    assert record.stats == [10, 12]
    assert record.cursor == "opaque-cursor"
    assert record.access_token == "synthetic-secret"
    refute inspect(record) =~ "synthetic-secret"

    for field <- [:started_at, :completed_at, :abandoned_at, :last_error_at] do
      assert Map.fetch!(record, field) == created
    end
  end

  test "source identity remains unique per import" do
    DataPlatformParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO data_import_items (data_import_id, source_provider, source_object_type, source_object_id, created_at, updated_at) VALUES (91001, 'fixture', 'contact', 'remote-1', now(), now())"
             )
  end

  test "polymorphic platform permissions remain unique" do
    DataPlatformParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO platform_app_permissibles (platform_app_id, permissible_id, permissible_type, created_at, updated_at) VALUES (91005, 7001, 'Account', now(), now())"
             )
  end
end
