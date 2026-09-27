defmodule Chatwooter.Accounts.CustomFilter do
  @moduledoc "Read mapping of upstream custom_filters; stored enum integers are preserved."
  use Ecto.Schema

  schema "custom_filters" do
    field :name, :string
    field :filter_type, :integer
    field :query, Chatwooter.Types.JsonValue
    field :account_id, :integer
    field :user_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
