defmodule Chatwooter.Accounts.UserSession do
  @moduledoc "Inactive read mapping of restored user_sessions."
  use Ecto.Schema

  schema "user_sessions" do
    field :user_id, :integer
    field :client_id, :string, redact: true
    field :ip_address, :string
    field :user_agent, :string
    field :browser_name, :string
    field :browser_version, :string
    field :device_name, :string
    field :platform_name, :string
    field :platform_version, :string
    field :city, :string
    field :country, :string
    field :country_code, :string
    field :last_activity_at, :naive_datetime_usec
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
