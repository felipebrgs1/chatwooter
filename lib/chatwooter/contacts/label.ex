defmodule Chatwooter.Contacts.Label do
  @moduledoc "Read-compatible mapping of upstream labels; IDs and timestamps are preserved."
  use Ecto.Schema

  schema "labels" do
    field :title, :string
    field :description, :string
    field :color, :string, default: "#1f93ff"
    field :show_on_sidebar, :boolean
    belongs_to :account, Chatwooter.Accounts.Account
    timestamps(type: :naive_datetime_usec, inserted_at: :created_at)
  end
end
