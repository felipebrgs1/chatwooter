defmodule Chatwooter.Platform.PlatformAppPermissible do
  @moduledoc "Inactive read mapping of upstream platform_app_permissibles; transfer uses pg_dump/pg_restore."
  use Ecto.Schema

  schema "platform_app_permissibles" do
    field :platform_app_id, :integer
    field :permissible_type, :string
    field :permissible_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
