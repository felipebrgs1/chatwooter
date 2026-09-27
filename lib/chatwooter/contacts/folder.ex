defmodule Chatwooter.Contacts.Folder do
  @moduledoc "Read mapping of upstream folders; stored values are preserved."
  use Ecto.Schema

  schema "folders" do
    field :account_id, :integer
    field :category_id, :integer
    field :name, :string
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
