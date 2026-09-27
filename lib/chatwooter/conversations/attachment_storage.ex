defmodule Chatwooter.Conversations.AttachmentStorage do
  @moduledoc "Application-owned storage metadata kept apart from restored upstream attachments."
  use Ecto.Schema
  @primary_key {:attachment_id, :id, autogenerate: false}

  schema "chatwooter_attachment_storage" do
    field :message_id, :integer
    field :key, :string
    field :url, :string
    field :content_type, :string
    field :size_bytes, :integer
    field :metadata, :map, default: %{}
  end
end
