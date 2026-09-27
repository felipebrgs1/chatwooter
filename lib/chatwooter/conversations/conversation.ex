defmodule Chatwooter.Conversations.Conversation do
  @moduledoc "Conversa entre um contato e a equipe dentro de um inbox."

  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(open pending resolved snoozed)a

  schema "conversations" do
    belongs_to :account, Chatwooter.Accounts.Account
    belongs_to :inbox, Chatwooter.Inboxes.Inbox

    field :status, Ecto.Enum,
      values: [open: 0, resolved: 1, pending: 2, snoozed: 3],
      default: :open

    belongs_to :assignee, Chatwooter.Accounts.User
    field :contact_id, :integer
    # Assigned by conversations_before_insert_row_tr; read back on insert.
    field :display_id, :integer, read_after_writes: true
    field :contact_last_seen_at, :utc_datetime_usec
    field :agent_last_seen_at, :utc_datetime_usec
    field :additional_attributes, Chatwooter.Types.JsonValue, default: %{}
    belongs_to :contact_inbox, Chatwooter.Contacts.ContactInbox
    field :uuid, Ecto.UUID
    field :identifier, :string
    field :last_activity_at, :utc_datetime_usec
    field :team_id, :integer
    field :campaign_id, :integer
    field :snoozed_until, :utc_datetime_usec
    field :custom_attributes, Chatwooter.Types.JsonValue, default: %{}
    field :assignee_last_seen_at, :utc_datetime_usec
    field :first_reply_created_at, :utc_datetime_usec
    field :priority, :integer
    field :sla_policy_id, :integer
    field :waiting_since, :utc_datetime_usec
    field :cached_label_list, :string
    field :assignee_agent_bot_id, :integer
    field :ai_assignee_type, :string
    field :status_changed_at, :utc_datetime_usec
    has_many :messages, Chatwooter.Conversations.Message
    # mensagens incoming não vistas pelo agente (máx. 10), preenchido na listagem
    field :unread_count, :integer, virtual: true, default: 0
    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
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
