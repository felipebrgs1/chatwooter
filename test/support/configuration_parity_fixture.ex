defmodule Chatwooter.ConfigurationParityFixture do
  @moduledoc false
  @created ~N[2026-09-24 10:30:00.123456]

  def rows do
    [
      {Chatwooter.Automations.AgentBot,
       %{
         id: 73_001,
         name: String.duplicate("b", 300),
         description: "Synthetic bot",
         outgoing_url: "https://example.test/bot",
         account_id: 7001,
         bot_config: [%{"key" => "synthetic-password"}],
         secret: "synthetic-bot-secret",
         created_at: @created,
         updated_at: @created
       }, %{bot_type: 0}},
      {Chatwooter.Automations.AgentBotInbox,
       %{
         id: 73_002,
         inbox_id: 7003,
         agent_bot_id: 73_001,
         account_id: 7001,
         created_at: @created,
         updated_at: @created
       }, %{status: 0}},
      {Chatwooter.Automations.AutomationRulePendingExecution,
       %{
         id: 73_003,
         automation_rule_id: 71_014,
         conversation_id: 7004,
         account_id: 7001,
         message_id: 7005,
         due_at: @created,
         episode_key: "fixture-episode",
         skip_reason: "Synthetic",
         created_at: @created,
         updated_at: @created
       }, %{status: 0}},
      {Chatwooter.Platform.EmailTemplate,
       %{
         id: 73_004,
         account_id: 7001,
         inbox_id: 7003,
         name: "welcome",
         body: "Synthetic body",
         created_at: @created,
         updated_at: @created
       }, %{template_type: 1, locale: 0}},
      {Chatwooter.Platform.InstallationConfig,
       %{
         id: 73_005,
         name: "FIXTURE",
         serialized_value: %{"value" => "synthetic-password"},
         created_at: @created,
         updated_at: @created
       }, %{locked: true}},
      {Chatwooter.Platform.PlatformBanner,
       %{
         id: 73_006,
         banner_message: "Synthetic announcement",
         created_at: @created,
         updated_at: @created
       }, %{banner_type: 0, active: true}},
      {Chatwooter.Conversations.ReportingEventsRollup,
       %{
         id: 73_007,
         account_id: 7001,
         date: ~D[2026-09-24],
         dimension_type: "Inbox",
         dimension_id: 7003,
         metric: "first_response",
         created_at: @created,
         updated_at: @created
       }, %{count: 0, sum_value: 0.0, sum_value_business_hours: 0.0}}
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
