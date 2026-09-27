defmodule Chatwooter.Platform.PlatformApp do
  @moduledoc "Inactive read mapping of upstream platform_apps; transfer uses pg_dump/pg_restore."
  use Ecto.Schema

  schema "platform_apps" do
    field :name, :string
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
