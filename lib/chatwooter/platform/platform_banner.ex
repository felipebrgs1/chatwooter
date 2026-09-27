defmodule Chatwooter.Platform.PlatformBanner do
  @moduledoc "Read mapping of upstream platform_banners; stored values are preserved."
  use Ecto.Schema

  schema "platform_banners" do
    field :banner_message, :string
    field :banner_type, :integer
    field :active, :boolean
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
