defmodule Chatwooter.Inboxes.InboxMember do
  @moduledoc "Vínculo entre inbox e agente da mesma conta."

  use Ecto.Schema
  import Ecto.Changeset

  schema "inbox_members" do
    belongs_to :inbox, Chatwooter.Inboxes.Inbox
    belongs_to :user, Chatwooter.Accounts.User

    timestamps(type: :naive_datetime_usec, inserted_at: :created_at)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:inbox_id, :user_id])
    |> validate_required([:inbox_id, :user_id])
    |> unique_constraint(:inbox_id, name: :index_inbox_members_on_inbox_id_and_user_id)
    |> foreign_key_constraint(:inbox_id)
    |> foreign_key_constraint(:user_id)
  end
end
