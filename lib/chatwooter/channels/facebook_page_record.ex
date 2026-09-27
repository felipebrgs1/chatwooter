defmodule Chatwooter.Channels.FacebookPageRecord do
  @moduledoc "Inactive read mapping of restored channel_facebook_pages; no channel adapter is enabled."
  use Ecto.Schema

  schema "channel_facebook_pages" do
    field :page_id, :string
    field :user_access_token, :string, redact: true
    field :page_access_token, :string, redact: true
    field :account_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :instagram_id, :string
    field :provider_name, :string
  end
end
