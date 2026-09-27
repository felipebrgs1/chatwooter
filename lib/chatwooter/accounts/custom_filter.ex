defmodule Chatwooter.Accounts.CustomFilter do
  @moduledoc "Saved views from Chatwoot's custom_filter.rb; stored enum integers are preserved."
  use Ecto.Schema
  import Ecto.Changeset

  schema "custom_filters" do
    field :name, :string
    field :filter_type, :integer, default: 0
    field :query, Chatwooter.Types.JsonValue
    field :account_id, :integer
    field :user_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end

  def changeset(filter, attrs) do
    filter
    |> cast(attrs, [:name, :filter_type, :query])
    |> validate_required([:name, :filter_type, :query])
    |> validate_inclusion(:filter_type, [0, 1, 2])
  end
end
