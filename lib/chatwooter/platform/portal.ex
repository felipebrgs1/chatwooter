defmodule Chatwooter.Platform.Portal do
  @moduledoc "Read mapping of upstream portals; help center compatibility without feature activation."
  use Ecto.Schema

  schema "portals" do
    field :account_id, :integer
    field :name, :string
    field :slug, :string
    field :custom_domain, :string
    field :color, :string
    field :homepage_link, :string
    field :page_title, :string
    field :header_text, :string
    field :config, :map
    field :archived, :boolean
    field :channel_web_widget_id, :integer
    field :ssl_settings, :map, redact: true
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
