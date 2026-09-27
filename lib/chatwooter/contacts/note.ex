defmodule Chatwooter.Contacts.Note do
  @moduledoc "Read-compatible mapping of upstream notes; IDs and timestamps are preserved."
  use Ecto.Schema
  import Ecto.Changeset

  schema "notes" do
    field :content, :string
    belongs_to :account, Chatwooter.Accounts.Account
    belongs_to :contact, Chatwooter.Contacts.Contact
    belongs_to :user, Chatwooter.Accounts.User
    timestamps(type: :naive_datetime_usec, inserted_at: :created_at)
  end

  @doc false
  def changeset(note, attrs) do
    note
    |> cast(attrs, [:content])
    |> update_change(:content, &String.trim/1)
    |> validate_required([:content])
  end
end
