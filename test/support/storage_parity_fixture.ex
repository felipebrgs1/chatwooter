defmodule Chatwooter.StorageParityFixture do
  @moduledoc false
  @created ~N[2026-09-24 10:30:00.123456]

  def rows do
    [
      {Chatwooter.Platform.ActiveStorageBlob,
       %{
         id: 91_001,
         key: "synthetic-blob",
         filename: "avatar.png",
         content_type: "image/png",
         metadata: "{\"description\":\"private-metadata\"}",
         byte_size: 5_000_000_000,
         checksum: "synthetic-checksum",
         created_at: @created,
         service_name: "local"
       }, %{}},
      {Chatwooter.Platform.ActiveStorageAttachment,
       %{
         id: 91_002,
         name: "avatar",
         record_type: "Contact",
         record_id: 5_000_000_001,
         blob_id: 91_001,
         created_at: @created
       }, %{}},
      {Chatwooter.Platform.ActiveStorageVariantRecord,
       %{id: 91_003, blob_id: 91_001, variation_digest: "synthetic-variation"}, %{}},
      {Chatwooter.Platform.ActionMailboxInboundEmail,
       %{
         id: 91_004,
         message_id: "synthetic@example.test",
         message_checksum: "email-checksum",
         created_at: @created,
         updated_at: @created
       }, %{status: 0}},
      {Chatwooter.Platform.Audit,
       %{
         id: 91_005,
         auditable_id: 5_000_000_002,
         auditable_type: "Conversation",
         associated_id: 7001,
         associated_type: "Account",
         user_id: 7002,
         user_type: "User",
         username: "Fixture",
         action: "update",
         audited_changes: %{"content" => ["old", "private-change"]},
         comment: "Imported audit",
         remote_address: "192.0.2.1",
         request_uuid: "synthetic-request",
         created_at: @created,
         city: "Fortaleza",
         country: "Brazil",
         country_code: "BR"
       }, %{version: 0}}
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
