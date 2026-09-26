defmodule Chatwooter.Contacts.ContactInbox do
  @moduledoc "Identidade de um contato dentro de um inbox (`source_id` = wa_id, telegram chat_id…)."

  use Ecto.Schema
  import Ecto.Changeset

  schema "contact_inboxes" do
    field :source_id, :string

    belongs_to :contact, Chatwooter.Contacts.Contact
    belongs_to :inbox, Chatwooter.Inboxes.Inbox

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(contact_inbox, attrs) do
    contact_inbox
    |> cast(attrs, [:contact_id, :inbox_id, :source_id])
    |> validate_required([:contact_id, :inbox_id, :source_id])
    |> unique_constraint([:inbox_id, :source_id])
    |> unique_constraint([:contact_id, :inbox_id])
    |> foreign_key_constraint(:contact_id)
    |> foreign_key_constraint(:inbox_id)
  end
end
