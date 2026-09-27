defmodule Chatwooter.Accounts.CustomRole do
  @moduledoc "Read mapping of upstream custom_roles; stored enum integers are preserved."
  use Ecto.Schema

  schema "custom_roles" do
    field :name, :string
    field :description, :string
    field :account_id, :integer
    field :permissions, {:array, :string}
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
