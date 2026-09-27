defmodule Chatwooter.Accounts.Leave do
  @moduledoc "Read mapping of upstream leaves; stored values are preserved."
  use Ecto.Schema

  schema "leaves" do
    field :account_id, :integer
    field :user_id, :integer
    field :start_date, :date
    field :end_date, :date
    field :leave_type, :integer
    field :status, :integer
    field :reason, :string
    field :approved_by_id, :integer
    field :approved_at, :naive_datetime_usec
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
