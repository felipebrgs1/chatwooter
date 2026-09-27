defmodule Chatwooter.Captain.Inbox do
  @moduledoc "Read mapping of upstream captain_inboxes; Captain stays out of scope."
  use Ecto.Schema

  schema "captain_inboxes" do
    field :captain_assistant_id, :integer
    field :inbox_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
