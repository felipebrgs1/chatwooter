defmodule Chatwooter.Platform.InstallationConfig do
  @moduledoc "Read mapping of upstream installation_configs; stored values are preserved."
  use Ecto.Schema

  schema "installation_configs" do
    field :name, :string
    field :serialized_value, Chatwooter.Types.JsonValue, redact: true
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :locked, :boolean
  end
end
