defmodule Chatwooter.Conversations.Message do
  @moduledoc "Mensagem de uma conversa (`incoming` contato→equipe, `outgoing` equipe→contato)."

  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(incoming outgoing activity)a

  schema "messages" do
    field :message_type, Ecto.Enum, values: @types, default: :incoming
    field :content, :string
    field :private, :boolean, default: false

    belongs_to :conversation, Chatwooter.Conversations.Conversation
    belongs_to :account, Chatwooter.Accounts.Account
    belongs_to :inbox, Chatwooter.Inboxes.Inbox
    belongs_to :sender, Chatwooter.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:message_type, :content, :private, :sender_id])
    |> validate_required([:message_type, :content])
    |> validate_length(:content, min: 1, max: 10_000)
    |> validate_inclusion(:message_type, @types)
    |> foreign_key_constraint(:conversation_id)
  end
end
