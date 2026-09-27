defmodule Chatwooter.CopilotChannelParityFixture do
  @moduledoc false
  @created ~N[2026-09-24 10:30:00.123456]

  def embedding, do: Pgvector.new(List.duplicate(0.5, 1536))

  def embedding_text, do: "[" <> Enum.map_join(1..1536, ",", fn _ -> "0.5" end) <> "]"

  def rows do
    [
      {Chatwooter.Platform.CopilotThread,
       %{
         id: 134_001,
         title: "Fixture thread",
         user_id: 7302,
         account_id: 7301,
         assistant_id: 131_001,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Platform.CopilotMessage,
       %{
         id: 134_002,
         copilot_thread_id: 134_001,
         account_id: 7301,
         message: %{"role" => "user", "content" => "hi"},
         message_type: 1,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Platform.ArticleEmbedding,
       %{
         id: 134_003,
         article_id: 134_010,
         term: "fixture term",
         embedding: embedding(),
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Channels.TiktokRecord,
       %{
         id: 134_004,
         account_id: 7301,
         business_id: "fixture-business",
         access_token: "synthetic-tiktok-token",
         expires_at: @created,
         refresh_token: "synthetic-tiktok-refresh",
         refresh_token_expires_at: @created,
         provider_name: "tiktok",
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Channels.TwilioSmsRecord,
       %{
         id: 134_005,
         phone_number: "+5511999999999",
         auth_token: "synthetic-twilio-auth",
         account_sid: "fixture-sid",
         account_id: 7301,
         medium: 1,
         messaging_service_sid: "fixture-service",
         api_key_sid: "fixture-key-sid",
         content_templates: %{"template" => "one"},
         content_templates_last_updated: @created,
         voice_enabled: true,
         twiml_app_sid: "fixture-twiml",
         api_key_secret: "synthetic-twilio-secret",
         provider_config: %{"token" => "synthetic-twilio-config"},
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Channels.TwitterProfileRecord,
       %{
         id: 134_006,
         profile_id: "fixture-profile",
         twitter_access_token: "synthetic-twitter-token",
         twitter_access_token_secret: "synthetic-twitter-secret",
         account_id: 7301,
         tweets_enabled: false,
         created_at: @created,
         updated_at: @created
       }, %{}}
    ]
  end

  def insert!(repo) do
    for {schema, attrs, _defaults} <- rows() do
      columns = Map.keys(attrs) |> Enum.sort()
      keys = Enum.map_join(columns, ", ", &Atom.to_string/1)
      placeholders = 1..length(columns) |> Enum.map_join(", ", &"$#{&1}")
      values = Enum.map(columns, &Map.fetch!(attrs, &1))
      table = schema.__schema__(:source)
      repo.query!("INSERT INTO #{table} (#{keys}) VALUES (#{placeholders})", values)
    end

    :ok
  end
end
