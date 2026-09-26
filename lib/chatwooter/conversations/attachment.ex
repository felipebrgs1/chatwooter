defmodule Chatwooter.Conversations.Attachment do
  @moduledoc "Arquivo de uma mensagem, hospedado no object storage (RustFS)."

  use Ecto.Schema
  import Ecto.Changeset

  schema "attachments" do
    field :file_type, :string
    field :key, :string
    field :url, :string
    field :content_type, :string
    field :size_bytes, :integer
    field :metadata, :map, default: %{}

    belongs_to :message, Chatwooter.Conversations.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:file_type, :key, :url, :content_type, :size_bytes, :metadata])
    |> validate_required([:file_type, :key, :url])
    |> unique_constraint([:message_id, :key])
    |> foreign_key_constraint(:message_id)
  end
end
