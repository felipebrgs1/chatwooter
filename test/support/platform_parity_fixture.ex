defmodule Chatwooter.PlatformParityFixture do
  @moduledoc false
  @created ~N[2026-09-24 10:30:00.123456]

  def rows do
    [
      {Chatwooter.Platform.AccessToken,
       %{
         id: 71_001,
         owner_type: "User",
         owner_id: 7002,
         token: "synthetic-token",
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Platform.Webhook,
       %{
         id: 71_002,
         account_id: 7001,
         inbox_id: 7003,
         url: "https://example.test/hooks",
         name:
           "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
         secret: "synthetic-secret",
         created_at: @created,
         updated_at: @created
       },
       %{
         webhook_type: 0,
         subscriptions: [
           "conversation_status_changed",
           "conversation_updated",
           "conversation_created",
           "contact_created",
           "contact_updated",
           "message_created",
           "message_updated",
           "webwidget_triggered"
         ]
       }},
      {Chatwooter.Notifications.Notification,
       %{
         id: 71_003,
         account_id: 7001,
         user_id: 7002,
         notification_type: 0,
         primary_actor_type: "Conversation",
         primary_actor_id: 7004,
         secondary_actor_type: "Message",
         secondary_actor_id: 7005,
         read_at: @created,
         snoozed_until: @created,
         meta: %{"reason" => "mention"},
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Notifications.NotificationSetting,
       %{
         id: 71_004,
         account_id: 7001,
         user_id: 7002,
         email_flags: 3,
         created_at: @created,
         updated_at: @created
       }, %{push_flags: 0}},
      {Chatwooter.Notifications.NotificationSubscription,
       %{
         id: 71_005,
         user_id: 7002,
         subscription_type: 0,
         identifier: "device-fixture",
         subscription_attributes: %{
           "endpoint" => "https://example.test/push",
           "keys" => %{"p256dh" => "synthetic"}
         },
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Contacts.Tag, %{id: 71_006, name: "vip", taggings_count: 2}, %{}},
      {Chatwooter.Contacts.Tagging,
       %{
         id: 71_007,
         tag_id: 71_006,
         taggable_type: "Conversation",
         taggable_id: 7004,
         tagger_type: "Account",
         tagger_id: 7001,
         context: "labels",
         created_at: @created
       }, %{}},
      {Chatwooter.Conversations.ConversationParticipant,
       %{
         id: 71_008,
         account_id: 7001,
         user_id: 7002,
         conversation_id: 7004,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Conversations.CsatSurveyResponse,
       %{
         id: 71_009,
         account_id: 7001,
         conversation_id: 7004,
         message_id: 7005,
         rating: 5,
         contact_id: 7006,
         assigned_agent_id: 7002,
         feedback_message: "Bom atendimento",
         csat_review_notes: "Revisado",
         review_notes_updated_at: @created,
         review_notes_updated_by_id: 7002,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Accounts.CustomFilter,
       %{
         id: 71_010,
         account_id: 7001,
         user_id: 7002,
         name: "Prioridade",
         filter_type: 2,
         query: [%{"attribute_key" => "status", "values" => ["open"]}],
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Accounts.CustomRole,
       %{
         id: 71_011,
         account_id: 7001,
         name: "Supervisor",
         permissions: ["conversation_manage", "contact_manage"],
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Platform.DashboardApp,
       %{
         id: 71_012,
         account_id: 7001,
         user_id: 7002,
         title: "CRM",
         content: [%{"type" => "frame", "url" => "https://example.test/app"}],
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Platform.IntegrationHook,
       %{
         id: 71_013,
         account_id: 7001,
         inbox_id: 7003,
         app_id: "fixture",
         access_token: "synthetic-access",
         settings: %{"enabled" => true},
         created_at: @created,
         updated_at: @created
       }, %{status: 1, hook_type: 0}},
      {Chatwooter.Automations.AutomationRule,
       %{
         id: 71_014,
         account_id: 7001,
         name: "Regra",
         event_name: "message_created",
         conditions: [%{"key" => "message_type", "value" => "incoming"}],
         actions: [%{"action_name" => "assign_team", "action_params" => [42]}],
         execution_delay: 60,
         created_at: @created,
         updated_at: @created
       }, %{active: true}},
      {Chatwooter.Automations.Macro,
       %{
         id: 71_015,
         account_id: 7001,
         name: "Resolver",
         visibility: 1,
         created_by_id: 7002,
         updated_by_id: 7002,
         actions: [%{"action_name" => "resolve_conversation"}],
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Notifications.Mention,
       %{
         id: 71_016,
         account_id: 7001,
         user_id: 7002,
         conversation_id: 7004,
         mentioned_at: @created,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Conversations.ReportingEvent,
       %{
         id: 71_017,
         account_id: 7001,
         user_id: 7002,
         inbox_id: 7003,
         conversation_id: 7004,
         name: "first_response",
         value: 12.5,
         value_in_business_hours: 10.25,
         event_start_time: @created,
         event_end_time: @created,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Conversations.SlaPolicy,
       %{
         id: 71_018,
         account_id: 7001,
         name: "Prioritário",
         first_response_time_threshold: 60.5,
         next_response_time_threshold: 120.0,
         resolution_time_threshold: 3600.0,
         created_at: @created,
         updated_at: @created
       }, %{only_during_business_hours: false}},
      {Chatwooter.Conversations.AppliedSla,
       %{
         id: 71_019,
         account_id: 7001,
         conversation_id: 7004,
         sla_policy_id: 71_018,
         completed_at: @created,
         created_at: @created,
         updated_at: @created
       }, %{sla_status: 0}},
      {Chatwooter.Conversations.SlaEvent,
       %{
         id: 71_020,
         account_id: 7001,
         conversation_id: 7004,
         sla_policy_id: 71_018,
         applied_sla_id: 71_019,
         inbox_id: 7003,
         event_type: 2,
         meta: %{"threshold" => 60.5},
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
