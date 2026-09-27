defmodule Chatwooter.Automations.CampaignRecipient do
  @moduledoc "Read mapping of upstream campaign_recipients; delivery state is preserved."
  use Ecto.Schema

  schema "campaign_recipients" do
    field :account_id, :integer
    field :campaign_id, :integer
    field :contact_id, :integer
    field :inbox_id, :integer
    field :source_id, :string
    field :status, :integer
    field :error_code, :string
    field :error_title, :string
    field :error_message, :string
    field :message_content, :string
    field :sent_at, :naive_datetime_usec
    field :delivered_at, :naive_datetime_usec
    field :read_at, :naive_datetime_usec
    field :failed_at, :naive_datetime_usec
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
