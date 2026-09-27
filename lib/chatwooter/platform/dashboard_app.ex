defmodule Chatwooter.Platform.DashboardApp do
  @moduledoc "Read mapping of upstream dashboard_apps; stored enum integers are preserved."
  use Ecto.Schema

  schema "dashboard_apps" do
    field :title, :string
    field :content, Chatwooter.Types.JsonValue
    field :account_id, :integer
    field :user_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
