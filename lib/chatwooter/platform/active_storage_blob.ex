defmodule Chatwooter.Platform.ActiveStorageBlob do
  @moduledoc "Read mapping of upstream active_storage_blobs; Rails compatibility only, without feature activation."
  use Ecto.Schema

  schema "active_storage_blobs" do
    field :key, :string
    field :filename, :string
    field :content_type, :string
    field :metadata, :string, redact: true
    field :byte_size, :integer
    field :checksum, :string
    field :created_at, :naive_datetime_usec
    field :service_name, :string
  end
end
