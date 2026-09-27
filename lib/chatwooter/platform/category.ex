defmodule Chatwooter.Platform.Category do
  @moduledoc "Read mapping of upstream categories; help center compatibility without feature activation."
  use Ecto.Schema

  schema "categories" do
    field :account_id, :integer
    field :portal_id, :integer
    field :position, :integer
    field :parent_category_id, :integer
    field :associated_category_id, :integer
    field :name, :string
    field :description, :string
    field :locale, :string
    field :slug, :string
    field :icon, :string
    field :icon_color, :string
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
