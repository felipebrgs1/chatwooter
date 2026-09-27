defmodule Chatwooter.Channels.TwitterProfileRecord do
  @moduledoc "Inactive read mapping of restored channel_twitter_profiles; no channel adapter is enabled."
  use Ecto.Schema

  schema "channel_twitter_profiles" do
    field :profile_id, :string
    field :twitter_access_token, :string, redact: true
    field :twitter_access_token_secret, :string, redact: true
    field :account_id, :integer
    field :tweets_enabled, :boolean
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
