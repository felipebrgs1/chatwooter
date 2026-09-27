defmodule Chatwooter.Platform.ActiveStorageVariantRecord do
  @moduledoc "Read mapping of upstream active_storage_variant_records; Rails compatibility only, without feature activation."
  use Ecto.Schema

  schema "active_storage_variant_records" do
    field :blob_id, :integer
    field :variation_digest, :string
  end
end
