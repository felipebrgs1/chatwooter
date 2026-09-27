defmodule Chatwooter.Contacts.Tagging do
  @moduledoc "Read mapping of upstream taggings; stored enum integers are preserved."
  use Ecto.Schema

  schema "taggings" do
    field :tag_id, :integer
    field :taggable_type, :string
    field :taggable_id, :integer
    field :tagger_type, :string
    field :tagger_id, :integer
    field :context, :string
    field :created_at, :naive_datetime_usec
  end
end
