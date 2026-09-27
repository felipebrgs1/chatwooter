defmodule Chatwooter.Platform.ActiveStorageAttachment do
  @moduledoc "Read mapping of upstream active_storage_attachments; Rails compatibility only, without feature activation."
  use Ecto.Schema

  schema "active_storage_attachments" do
    field :name, :string
    field :record_type, :string
    field :record_id, :integer
    field :blob_id, :integer
    field :created_at, :naive_datetime_usec
  end
end
