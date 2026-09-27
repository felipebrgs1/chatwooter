defmodule Chatwooter.Captain.Document do
  @moduledoc "Read mapping of upstream captain_documents; Captain stays out of scope."
  use Ecto.Schema

  schema "captain_documents" do
    field :name, :string
    field :external_link, :string
    field :content, :string
    field :assistant_id, :integer
    field :account_id, :integer
    field :status, :integer
    field :metadata, Chatwooter.Types.JsonValue
    field :sync_status, :integer
    field :last_synced_at, :naive_datetime_usec
    field :last_sync_attempted_at, :naive_datetime_usec
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
