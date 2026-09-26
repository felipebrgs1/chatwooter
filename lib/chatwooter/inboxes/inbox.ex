defmodule Chatwooter.Inboxes.Inbox do
  @moduledoc "Caixa de entrada de um canal (fase 1: `whatsapp` | `telegram`)."

  use Ecto.Schema
  import Ecto.Changeset

  @channel_types ~w(whatsapp telegram)a

  schema "inboxes" do
    field :name, :string
    field :channel_type, Ecto.Enum, values: @channel_types
    field :provider_config, :map, default: %{}
    field :greeting_message, :string

    belongs_to :account, Chatwooter.Accounts.Account
    has_many :contact_inboxes, Chatwooter.Contacts.ContactInbox

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(inbox, attrs) do
    inbox
    |> cast(attrs, [:name, :channel_type, :provider_config, :greeting_message])
    |> validate_required([:name, :channel_type])
    |> validate_length(:name, min: 2, max: 160)
    |> validate_inclusion(:channel_type, @channel_types)
    |> foreign_key_constraint(:account_id)
  end
end
