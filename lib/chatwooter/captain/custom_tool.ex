defmodule Chatwooter.Captain.CustomTool do
  @moduledoc "Read mapping of upstream captain_custom_tools; Captain stays out of scope."
  use Ecto.Schema

  schema "captain_custom_tools" do
    field :account_id, :integer
    field :slug, :string
    field :title, :string
    field :description, :string
    field :http_method, :string
    field :endpoint_url, :string
    field :request_template, :string
    field :response_template, :string
    field :auth_type, :string
    field :auth_config, Chatwooter.Types.JsonValue, redact: true
    field :param_schema, Chatwooter.Types.JsonValue
    field :enabled, :boolean
    field :assistant_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
