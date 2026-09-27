defmodule Chatwooter.Accounts.AssignmentPolicy do
  @moduledoc "Read mapping of upstream assignment_policies; stored values are preserved."
  use Ecto.Schema

  schema "assignment_policies" do
    field :account_id, :integer
    field :name, :string
    field :description, :string
    field :assignment_order, :integer
    field :conversation_priority, :integer
    field :fair_distribution_limit, :integer
    field :fair_distribution_window, :integer
    field :enabled, :boolean
    field :exclude_older_than_hours, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
