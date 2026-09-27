defmodule Chatwooter.Automations.Campaign do
  @moduledoc "Read mapping of upstream campaigns; campaign execution stays out of scope."
  use Ecto.Schema

  schema "campaigns" do
    field :display_id, :integer
    field :title, :string
    field :description, :string
    field :message, :string
    field :sender_id, :integer
    field :enabled, :boolean
    field :account_id, :integer
    field :inbox_id, :integer
    field :trigger_rules, Chatwooter.Types.JsonValue
    field :campaign_type, :integer
    field :campaign_status, :integer
    field :audience, Chatwooter.Types.JsonValue
    field :scheduled_at, :naive_datetime
    field :trigger_only_during_business_hours, :boolean
    field :template_params, Chatwooter.Types.JsonValue
    field :started_at, :naive_datetime_usec
    field :completed_at, :naive_datetime_usec
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
