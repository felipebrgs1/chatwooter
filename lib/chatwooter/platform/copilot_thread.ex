defmodule Chatwooter.Platform.CopilotThread do
  @moduledoc "Read mapping of upstream copilot_threads; Copilot stays out of scope."
  use Ecto.Schema

  schema "copilot_threads" do
    field :title, :string
    field :user_id, :integer
    field :account_id, :integer
    field :assistant_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
