defmodule Chatwooter.Contacts.ContactInbox do
  @moduledoc "Identidade de um contato dentro de um inbox (`source_id` = wa_id, telegram chat_id…)."

  use Ecto.Schema
  import Ecto.Changeset

  alias Chatwooter.Contacts.Contact
  alias Chatwooter.Inboxes.Inbox
  alias Chatwooter.Repo

  schema "contact_inboxes" do
    field :source_id, :string
    field :hmac_verified, :boolean, default: false
    field :pubsub_token, :string, redact: true

    belongs_to :contact, Contact
    belongs_to :inbox, Inbox

    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end

  @doc false
  def changeset(contact_inbox, attrs) do
    contact_inbox
    |> cast(attrs, [:contact_id, :inbox_id, :source_id])
    |> validate_required([:contact_id, :inbox_id, :source_id])
    |> unique_constraint([:inbox_id, :source_id],
      name: :index_contact_inboxes_on_inbox_id_and_source_id
    )
    |> unique_constraint(:pubsub_token, name: :index_contact_inboxes_on_pubsub_token)
    |> validate_parents()
  end

  defp validate_parents(changeset) do
    contact =
      get_field(changeset, :contact_id) && Repo.get(Contact, get_field(changeset, :contact_id))

    inbox = get_field(changeset, :inbox_id) && Repo.get(Inbox, get_field(changeset, :inbox_id))

    changeset =
      if contact, do: changeset, else: add_error(changeset, :contact_id, "does not exist")

    changeset = if inbox, do: changeset, else: add_error(changeset, :inbox_id, "does not exist")

    if contact && inbox && contact.account_id != inbox.account_id do
      add_error(changeset, :inbox_id, "does not belong to this account")
    else
      changeset
    end
  end
end
