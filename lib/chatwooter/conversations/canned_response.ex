defmodule Chatwooter.Conversations.CannedResponse do
  @moduledoc "Read-compatible mapping of upstream canned_responses; IDs and timestamps are preserved."
  use Ecto.Schema

  schema "canned_responses" do
    field :short_code, :string
    field :content, :string
    belongs_to :account, Chatwooter.Accounts.Account
    timestamps(type: :naive_datetime_usec, inserted_at: :created_at)
  end
end
