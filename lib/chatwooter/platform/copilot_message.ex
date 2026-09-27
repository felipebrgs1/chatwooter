defmodule Chatwooter.Platform.CopilotMessage do
  @moduledoc "Read mapping of upstream copilot_messages; Copilot stays out of scope."
  use Ecto.Schema

  schema "copilot_messages" do
    field :copilot_thread_id, :integer
    field :account_id, :integer
    field :message, Chatwooter.Types.JsonValue
    field :message_type, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
