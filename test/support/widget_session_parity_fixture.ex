defmodule Chatwooter.WidgetSessionParityFixture do
  @moduledoc false
  @created ~N[2026-09-24 10:30:00.123456]

  def rows do
    [
      {Chatwooter.Channels.WebWidgetRecord,
       %{
         id: 95_001,
         account_id: 7001,
         website_url: "https://example.test",
         website_token: "synthetic-widget-token",
         welcome_title: "Olá",
         welcome_tagline: "Como podemos ajudar?",
         hmac_token: "synthetic-widget-hmac",
         pre_chat_form_options: %{"fields" => [%{"name" => "email"}]},
         allowed_domains: "example.test\nexample.org",
         created_at: @created,
         updated_at: @created
       },
       %{
         widget_color: "#1f93ff",
         feature_flags: 7,
         reply_time: 0,
         pre_chat_form_enabled: false,
         hmac_mandatory: false,
         continuity_via_email: true
       }},
      {Chatwooter.Accounts.UserSession,
       %{
         id: 95_002,
         user_id: 7002,
         client_id: "synthetic-client",
         ip_address: "192.0.2.2",
         user_agent: "Fixture",
         browser_name: "Firefox",
         browser_version: "1",
         device_name: "Desktop",
         platform_name: "Linux",
         platform_version: "1",
         city: "Fortaleza",
         country: "Brazil",
         country_code: "BR",
         last_activity_at: @created,
         created_at: @created,
         updated_at: @created
       }, %{}}
    ]
  end

  def insert!(repo) do
    repo.query!(
      "INSERT INTO users (id, name, email, created_at, updated_at) VALUES (7002, 'Session fixture', 'session-fixture@example.test', now(), now()) ON CONFLICT (id) DO NOTHING"
    )

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
