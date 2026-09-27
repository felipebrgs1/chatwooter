defmodule Chatwooter.Conversations.Message do
  @moduledoc "Mensagem de uma conversa (`incoming` contato→equipe, `outgoing` equipe→contato)."

  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(incoming outgoing activity template)a
  @content_types ~w(text image audio video file location input_text input_textarea input_email input_select cards form article incoming_email input_csat integrations sticker voice_call)a
  @statuses ~w(sent delivered read failed)a

  schema "messages" do
    field :content, :string
    belongs_to :account, Chatwooter.Accounts.Account
    belongs_to :inbox, Chatwooter.Inboxes.Inbox
    belongs_to :conversation, Chatwooter.Conversations.Conversation

    field :message_type, Ecto.Enum,
      values: [incoming: 0, outgoing: 1, activity: 2, template: 3],
      default: :incoming

    field :private, :boolean, default: false
    field :status, Ecto.Enum, values: [sent: 0, delivered: 1, read: 2, failed: 3], default: :sent
    field :source_id, :string

    field :upstream_content_type, Ecto.Enum,
      source: :content_type,
      values: [
        text: 0,
        input_text: 1,
        input_textarea: 2,
        input_email: 3,
        input_select: 4,
        cards: 5,
        form: 6,
        article: 7,
        incoming_email: 8,
        input_csat: 9,
        integrations: 10,
        sticker: 11,
        voice_call: 12
      ],
      default: :text

    field :content_attributes, Chatwooter.Types.JsonValue, default: %{}
    field :sender_type, :string
    belongs_to :sender, Chatwooter.Accounts.User
    field :external_source_ids, Chatwooter.Types.JsonValue, default: %{}
    field :additional_attributes, Chatwooter.Types.JsonValue, default: %{}
    field :processed_message_content, :string
    field :sentiment, Chatwooter.Types.JsonValue, default: %{}
    has_many :attachments, Chatwooter.Conversations.Attachment
    field :content_type, Ecto.Enum, values: @content_types, virtual: true, default: :text
    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :message_type,
      :content,
      :content_type,
      :status,
      :private,
      :sender_id,
      :source_id,
      :sender_type
    ])
    # Conteúdo é nulo em mídia sem legenda; texto vazio do dashboard é
    # barrado no LiveView antes de chegar aqui.
    |> validate_required([:message_type])
    |> validate_length(:content, max: 10_000)
    |> validate_inclusion(:message_type, @types)
    |> validate_inclusion(:content_type, @content_types)
    |> validate_inclusion(:status, @statuses)
    |> preserve_media_type()
    |> infer_sender_type()
    |> foreign_key_constraint(:conversation_id)
  end

  defp infer_sender_type(changeset) do
    if get_field(changeset, :sender_id) && is_nil(get_field(changeset, :sender_type)) do
      put_change(changeset, :sender_type, "User")
    else
      changeset
    end
  end

  defp preserve_media_type(changeset) do
    case get_field(changeset, :content_type) do
      type when type in [:image, :audio, :video, :file, :location] ->
        put_change(
          changeset,
          :content_attributes,
          Map.put(
            get_field(changeset, :content_attributes) || %{},
            "chatwooter_media_type",
            to_string(type)
          )
        )

      type ->
        if get_change(changeset, :content_type) do
          put_change(changeset, :upstream_content_type, type)
        else
          changeset
        end
    end
  end

  def hydrate(message) do
    type =
      case message.content_attributes do
        %{"chatwooter_media_type" => value} when value in ~w(image audio video file location) ->
          Enum.find([:image, :audio, :video, :file, :location], &(to_string(&1) == value))

        _ ->
          message.upstream_content_type
      end

    %{message | content_type: type}
  end
end
