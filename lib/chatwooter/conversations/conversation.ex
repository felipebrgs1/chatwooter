defmodule Chatwooter.Conversations.Conversation do
  @moduledoc "Conversa entre um contato e a equipe dentro de um inbox."

  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(open pending resolved)a

  schema "conversations" do
    field :status, Ecto.Enum, values: @statuses, default: :open
    field :last_activity_at, :utc_datetime

    belongs_to :account, Chatwooter.Accounts.Account
    belongs_to :inbox, Chatwooter.Inboxes.Inbox
    belongs_to :contact_inbox, Chatwooter.Contacts.ContactInbox
    has_many :messages, Chatwooter.Conversations.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:status, :last_activity_at])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:inbox_id)
    |> foreign_key_constraint(:contact_inbox_id)
  end
end
