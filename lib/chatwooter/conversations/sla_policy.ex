defmodule Chatwooter.Conversations.SlaPolicy do
  @moduledoc "Read mapping of upstream sla_policies; stored enum integers are preserved."
  use Ecto.Schema

  schema "sla_policies" do
    field :name, :string
    field :first_response_time_threshold, :float
    field :next_response_time_threshold, :float
    field :only_during_business_hours, :boolean
    field :account_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :description, :string
    field :resolution_time_threshold, :float
  end
end
