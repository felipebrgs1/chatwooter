defmodule Chatwooter.PreservedChannelsParityFixture do
  @moduledoc false
  @created ~N[2026-09-24 10:30:00.123456]

  def rows do
    common = %{account_id: 7001, created_at: @created, updated_at: @created}

    [
      {Chatwooter.Channels.ApiRecord,
       Map.merge(common, %{
         id: 101_001,
         webhook_url: String.duplicate("w", 300),
         identifier: "api-fixture",
         hmac_token: "synthetic-hmac",
         secret: "synthetic-api-secret"
       }), %{hmac_mandatory: false, additional_attributes: %{}}},
      {Chatwooter.Channels.EmailRecord,
       Map.merge(common, %{
         id: 101_002,
         email: "fixture@example.test",
         forward_to_email: "forward@example.test",
         imap_password: "synthetic-imap-password",
         smtp_password: "synthetic-smtp-password",
         provider_config: %{"token" => "synthetic-email-config"}
       }),
       %{
         imap_enabled: false,
         imap_address: "",
         imap_port: 0,
         imap_login: "",
         imap_enable_ssl: true,
         smtp_enabled: false,
         smtp_address: "",
         smtp_port: 0,
         smtp_login: "",
         smtp_domain: "",
         smtp_enable_starttls_auto: true,
         smtp_authentication: "login",
         smtp_openssl_verify_mode: "none",
         smtp_enable_ssl_tls: false,
         provider: nil,
         imap_authentication: "plain",
         verified_for_sending: false
       }},
      {Chatwooter.Channels.FacebookPageRecord,
       Map.merge(common, %{
         id: 101_003,
         page_id: "page-fixture",
         user_access_token: "synthetic-user-token",
         page_access_token: "synthetic-page-token",
         instagram_id: "instagram-fixture",
         provider_name: "facebook"
       }), %{}},
      {Chatwooter.Channels.InstagramRecord,
       Map.merge(common, %{
         id: 101_004,
         access_token: "synthetic-instagram-token",
         expires_at: @created,
         instagram_id: "instagram-fixture",
         provider_name: "instagram"
       }), %{}},
      {Chatwooter.Channels.LineRecord,
       Map.merge(common, %{
         id: 101_005,
         line_channel_id: "line-fixture",
         line_channel_secret: "synthetic-line-secret",
         line_channel_token: "synthetic-line-token"
       }), %{}},
      {Chatwooter.Channels.SmsRecord,
       Map.merge(common, %{
         id: 101_006,
         phone_number: "+5511999999999",
         provider_config: %{"token" => "synthetic-sms-config"}
       }), %{provider: "default"}}
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
