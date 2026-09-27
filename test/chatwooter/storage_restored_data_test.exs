defmodule Chatwooter.StorageRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.Platform.ActiveStorageBlob
  alias Chatwooter.Platform.Audit
  alias Chatwooter.StorageParityFixture

  test "restored rows preserve IDs, polymorphic class names, timestamps and defaults" do
    StorageParityFixture.insert!(Repo)

    for {schema, attrs, defaults} <- StorageParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "nullable audit fields remain nil" do
    Repo.query!("INSERT INTO audits (id) VALUES (92001)")
    record = Repo.get!(Audit, 92_001)
    assert record.version == 0

    for field <- Audit.__schema__(:fields) -- [:id, :version] do
      assert Map.fetch!(record, field) == nil, Atom.to_string(field)
    end
  end

  test "attachment references require an existing blob" do
    assert {:error, %Postgrex.Error{postgres: %{code: :foreign_key_violation}}} =
             Repo.query(
               "INSERT INTO active_storage_attachments (name, record_type, record_id, blob_id, created_at) VALUES ('avatar', 'Contact', 7, 999999, now())"
             )
  end

  test "sensitive storage metadata and audited changes are redacted from inspection" do
    StorageParityFixture.insert!(Repo)
    refute inspect(Repo.get!(ActiveStorageBlob, 91_001)) =~ "private-metadata"
    refute inspect(Repo.get!(Audit, 91_005)) =~ "private-change"
  end
end
