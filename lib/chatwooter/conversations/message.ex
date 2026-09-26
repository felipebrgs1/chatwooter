defmodule Chatwooter.Conversations.Message do
  @moduledoc "Mensagem de uma conversa (`incoming` contato→equipe, `outgoing` equipe→contato)."

  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(incoming outgoing activity)a
  @content_types ~w(text image audio video file location)a
  @statuses ~w(sent delivered read failed)a

  schema "messages" do
    field :message_type, Ecto.Enum, values: @types, default: :incoming
    field :content_type, Ecto.Enum, values: @content_types, default: :text
    field :status, Ecto.Enum, values: @statuses
    field :content, :string
    field :private, :boolean, default: false
    # ID no provider (wamid, telegram message_id…). Nulo p/ mensagens do dashboard.
    field :source_id, :string

    belongs_to :conversation, Chatwooter.Conversations.Conversation
    belongs_to :account, Chatwooter.Accounts.Account
    belongs_to :inbox, Chatwooter.Inboxes.Inbox
    belongs_to :sender, Chatwooter.Accounts.User
    has_many :attachments, Chatwooter.Conversations.Attachment

    timestamps(type: :utc_datetime)
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
      :source_id
    ])
    # Conteúdo é nulo em mídia sem legenda; texto vazio do dashboard é
    # barrado no LiveView antes de chegar aqui.
    |> validate_required([:message_type])
    |> validate_length(:content, max: 10_000)
    |> validate_inclusion(:message_type, @types)
    |> validate_inclusion(:content_type, @content_types)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:conversation_id, :source_id])
    |> foreign_key_constraint(:conversation_id)
  end
end
