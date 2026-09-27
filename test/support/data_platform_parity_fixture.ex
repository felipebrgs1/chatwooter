defmodule Chatwooter.DataPlatformParityFixture do
  @moduledoc false
  @created ~N[2026-09-24 10:30:00.123456]

  def rows do
    common = %{created_at: @created, updated_at: @created}

    [
      {Chatwooter.Platform.DataImport,
       Map.merge(common, %{
         id: 91_001,
         account_id: 7001,
         data_type: "contacts",
         name: String.duplicate("x", 300),
         source_type: "dump",
         source_provider: "fixture"
       }), %{status: 0, import_types: [], source_metadata: %{}, stats: %{}, cursor: %{}}},
      {Chatwooter.Platform.DataImportItem,
       Map.merge(common, %{
         id: 91_002,
         data_import_id: 91_001,
         source_provider: "fixture",
         source_object_type: "contact",
         source_object_id: "remote-1",
         chatwoot_record_type: "Contact",
         chatwoot_record_id: 7002,
         metadata: [%{"source" => "dump"}]
       }), %{status: 0, attempt_count: 0}},
      {Chatwooter.Platform.DataImportMapping,
       Map.merge(common, %{
         id: 91_003,
         account_id: 7001,
         data_import_id: 91_001,
         source_provider: "fixture",
         source_object_type: "contact",
         source_object_id: "remote-1",
         chatwoot_record_type: "Contact",
         chatwoot_record_id: 7002
       }), %{metadata: %{}}},
      {Chatwooter.Platform.DataImportError,
       Map.merge(common, %{
         id: 91_004,
         data_import_id: 91_001,
         data_import_item_id: 91_002,
         source_object_type: "contact",
         source_object_id: "remote-1",
         error_code: "fixture",
         message: "Synthetic diagnostic"
       }), %{details: %{}}},
      {Chatwooter.Platform.PlatformApp,
       Map.merge(common, %{id: 91_005, name: String.duplicate("a", 300)}), %{}},
      {Chatwooter.Platform.PlatformAppPermissible,
       Map.merge(common, %{
         id: 91_006,
         platform_app_id: 91_005,
         permissible_type: "Account",
         permissible_id: 7001
       }), %{}}
    ]
  end

  def insert!(repo) do
    for {schema, attrs, _defaults} <- rows() do
      columns = Map.keys(attrs) |> Enum.sort()
      keys = Enum.map_join(columns, ", ", &Atom.to_string/1)
      placeholders = 1..length(columns) |> Enum.map_join(", ", &"$#{&1}")
      values = Enum.map(columns, &Map.fetch!(attrs, &1))
      table = schema.__schema__(:source)
      repo.query!("INSERT INTO #{table} (#{keys}) VALUES (#{placeholders})", values)
    end

    :ok
  end
end
