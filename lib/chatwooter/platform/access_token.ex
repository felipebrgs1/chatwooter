defmodule Chatwooter.Platform.AccessToken do
  @moduledoc "Read mapping of upstream access_tokens; stored enum integers are preserved."
  use Ecto.Schema

  schema "access_tokens" do
    field :owner_type, :string
    field :owner_id, :integer
    field :token, :string, redact: true
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
