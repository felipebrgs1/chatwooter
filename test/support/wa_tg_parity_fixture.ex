defmodule Chatwooter.WaTgParityFixture do
  @moduledoc false
  @created ~N[2026-09-24 10:30:00.123456]

  def rows do
    [
      {Chatwooter.Channels.WhatsAppRecord,
       %{
         id: 94_001,
         account_id: 7001,
         phone_number: "+5585999990001",
         provider: "whatsapp_cloud",
         business_management_token: "synthetic-business-token",
         provider_config: %{"phone_number_id" => "synthetic-id"},
         message_templates: [%{"name" => "welcome", "status" => "APPROVED"}],
         message_templates_last_updated: @created,
         phone_number_health: %{"status" => "GREEN"},
         phone_number_health_checked_at: @created,
         phone_number_health_error: String.duplicate("a", 500),
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Channels.TelegramRecord,
       %{
         id: 94_002,
         account_id: 7001,
         bot_name: "fixture_bot",
         bot_token: "synthetic-bot-token",
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
