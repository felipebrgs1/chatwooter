defmodule Chatwooter.Conversations.Attachment do
  @moduledoc "Arquivo de uma mensagem, hospedado no object storage (RustFS)."

  use Ecto.Schema
  import Ecto.Changeset

  schema "attachments" do
    field :file_type, Ecto.Enum,
      values: [
        image: 0,
        audio: 1,
        video: 2,
        file: 3,
        location: 4,
        fallback: 5,
        share: 6,
        story_mention: 7,
        contact: 8,
        ig_reel: 9,
        ig_post: 10,
        ig_story: 11,
        embed: 12
      ]

    field :external_url, :string
    field :coordinates_lat, :float
    field :coordinates_long, :float
    belongs_to :message, Chatwooter.Conversations.Message
    field :account_id, :integer
    field :fallback_title, :string
    field :extension, :string
    field :meta, Chatwooter.Types.JsonValue, default: %{}
    field :key, :string, virtual: true
    field :url, :string, virtual: true
    field :content_type, :string, virtual: true
    field :size_bytes, :integer, virtual: true
    field :metadata, :map, virtual: true, default: %{}
    has_one :storage, Chatwooter.Conversations.AttachmentStorage
    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end

  @doc false
  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:file_type, :key, :url, :content_type, :size_bytes, :metadata])
    |> validate_required([:file_type, :key, :url])
    |> foreign_key_constraint(:message_id)
  end
end
