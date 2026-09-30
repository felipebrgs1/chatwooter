-- name: ListInboxes :many
-- InboxesController#index: policy_scope (admin vê todas; agente só as de inbox_members) + order_by_name.
-- Só colunas públicas do canal: tokens e provider_config nunca saem daqui (ficam em models.InboxConfigs).
SELECT i.id, i.channel_id, i.name, i.channel_type, i.greeting_enabled, i.greeting_message, i.working_hours_enabled,
       i.enable_email_collect, i.csat_survey_enabled, i.csat_config, i.enable_auto_assignment, i.auto_assignment_config,
       i.out_of_office_message, i.timezone, i.allow_messages_after_resolved, i.lock_to_single_conversation,
       i.sender_name_type, i.business_name,
       tg.bot_name, wa.phone_number, wa.provider, wa.message_templates,
       COALESCE((SELECT jsonb_agg(jsonb_build_object(
                   'day_of_week', wh.day_of_week, 'closed_all_day', wh.closed_all_day,
                   'open_hour', wh.open_hour, 'open_minutes', wh.open_minutes,
                   'close_hour', wh.close_hour, 'close_minutes', wh.close_minutes,
                   'open_all_day', wh.open_all_day) ORDER BY wh.day_of_week)
                 FROM working_hours wh WHERE wh.inbox_id = i.id), '[]')::jsonb AS working_hours
FROM inboxes i
LEFT JOIN channel_telegram tg ON i.channel_type = 'Channel::Telegram' AND tg.id = i.channel_id
LEFT JOIN channel_whatsapp wa ON i.channel_type = 'Channel::Whatsapp' AND wa.id = i.channel_id
WHERE i.account_id = sqlc.arg(account_id)
  AND (sqlc.narg(member_id)::int IS NULL
       OR i.id IN (SELECT im.inbox_id FROM inbox_members im WHERE im.user_id = sqlc.narg(member_id)::int))
ORDER BY lower(i.name);
