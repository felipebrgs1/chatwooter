defmodule Chatwooter.Platform.IntegrationHook do
  @moduledoc "Read mapping of upstream integrations_hooks; stored enum integers are preserved."
  use Ecto.Schema

  schema "integrations_hooks" do
    field :status, :integer
    field :inbox_id, :integer
    field :account_id, :integer
    field :app_id, :string
    field :hook_type, :integer
    field :reference_id, :string
    field :access_token, :string, redact: true
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :settings, Chatwooter.Types.JsonValue
  end
end
