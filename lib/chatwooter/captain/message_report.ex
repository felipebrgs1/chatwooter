defmodule Chatwooter.Captain.MessageReport do
  @moduledoc "Read mapping of upstream captain_message_reports; Captain stays out of scope."
  use Ecto.Schema

  schema "captain_message_reports" do
    field :account_id, :integer
    field :conversation_id, :integer
    field :message_id, :integer
    field :user_id, :integer
    field :report_reason, :string
    field :description, :string
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
