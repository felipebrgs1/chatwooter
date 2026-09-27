defmodule Chatwooter.Platform.Audit do
  @moduledoc "Read mapping of upstream audits; Rails compatibility only, without feature activation."
  use Ecto.Schema

  schema "audits" do
    field :auditable_id, :integer
    field :associated_id, :integer
    field :user_id, :integer
    field :version, :integer
    field :auditable_type, :string
    field :associated_type, :string
    field :user_type, :string
    field :username, :string
    field :action, :string
    field :comment, :string
    field :remote_address, :string
    field :request_uuid, :string
    field :city, :string
    field :country, :string
    field :country_code, :string
    field :audited_changes, :map, redact: true
    field :created_at, :naive_datetime_usec
  end
end
