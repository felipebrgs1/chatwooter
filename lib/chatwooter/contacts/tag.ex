defmodule Chatwooter.Contacts.Tag do
  @moduledoc "Read mapping of upstream tags; stored enum integers are preserved."
  use Ecto.Schema

  schema "tags" do
    field :name, :string
    field :taggings_count, :integer
  end
end
