defmodule Chatwooter.Platform.RelatedCategory do
  @moduledoc "Read mapping of upstream related_categories; help center compatibility without feature activation."
  use Ecto.Schema

  schema "related_categories" do
    field :category_id, :integer
    field :related_category_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
