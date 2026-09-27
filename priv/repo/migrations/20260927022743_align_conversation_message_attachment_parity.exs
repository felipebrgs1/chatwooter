defmodule Chatwooter.Repo.Migrations.AlignConversationMessageAttachmentParity do
  use Ecto.Migration

  def up do
    execute "DO $$ DECLARE c record; BEGIN FOR c IN SELECT conname FROM pg_constraint WHERE conrelid = 'conversations'::regclass AND contype = 'f' LOOP EXECUTE format('ALTER TABLE conversations DROP CONSTRAINT %I', c.conname); END LOOP; END $$"
    execute "DROP INDEX conversations_account_id_status_index"
    execute "ALTER TABLE conversations RENAME COLUMN inserted_at TO created_at"

    execute "DO $$ DECLARE c record; BEGIN FOR c IN SELECT conname FROM pg_constraint WHERE conrelid = 'messages'::regclass AND contype = 'f' LOOP EXECUTE format('ALTER TABLE messages DROP CONSTRAINT %I', c.conname); END LOOP; END $$"

    execute "DROP INDEX messages_conversation_id_index"
    execute "DROP INDEX messages_conversation_id_source_id_index"
    execute "ALTER TABLE messages RENAME COLUMN inserted_at TO created_at"

    execute "DO $$ DECLARE c record; BEGIN FOR c IN SELECT conname FROM pg_constraint WHERE conrelid = 'attachments'::regclass AND contype = 'f' LOOP EXECUTE format('ALTER TABLE attachments DROP CONSTRAINT %I', c.conname); END LOOP; END $$"

    execute "DROP INDEX attachments_message_id_index"
    execute "DROP INDEX attachments_message_id_key_index"
    execute "ALTER TABLE attachments RENAME COLUMN inserted_at TO created_at"

    execute "CREATE TABLE chatwooter_attachment_storage (attachment_id integer PRIMARY KEY, message_id integer NOT NULL, key varchar NOT NULL, url varchar NOT NULL, content_type varchar, size_bytes integer, metadata jsonb NOT NULL DEFAULT '{}'::jsonb)"

    execute "INSERT INTO chatwooter_attachment_storage SELECT id, message_id, key, url, content_type, size_bytes, metadata FROM attachments"

    execute "CREATE UNIQUE INDEX chatwooter_attachment_storage_message_key ON chatwooter_attachment_storage (message_id, key)"

    execute "ALTER TABLE attachments DROP COLUMN key"
    execute "ALTER TABLE attachments DROP COLUMN url"
    execute "ALTER TABLE attachments DROP COLUMN content_type"
    execute "ALTER TABLE attachments DROP COLUMN size_bytes"
    execute "ALTER TABLE attachments DROP COLUMN metadata"
    execute "ALTER TABLE conversations ALTER COLUMN account_id DROP DEFAULT"

    execute "ALTER TABLE conversations ALTER COLUMN account_id TYPE integer USING (account_id)::integer"

    execute "ALTER TABLE conversations ALTER COLUMN account_id SET NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN additional_attributes jsonb DEFAULT '{}'::jsonb"
    execute "ALTER TABLE conversations ALTER COLUMN additional_attributes DROP NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN agent_last_seen_at timestamp"
    execute "ALTER TABLE conversations ALTER COLUMN agent_last_seen_at DROP NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN ai_assignee_type varchar"
    execute "ALTER TABLE conversations ALTER COLUMN ai_assignee_type DROP NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN assignee_agent_bot_id bigint"
    execute "ALTER TABLE conversations ALTER COLUMN assignee_agent_bot_id DROP NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN assignee_id integer"
    execute "ALTER TABLE conversations ALTER COLUMN assignee_id DROP NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN assignee_last_seen_at timestamp"
    execute "ALTER TABLE conversations ALTER COLUMN assignee_last_seen_at DROP NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN cached_label_list text"
    execute "ALTER TABLE conversations ALTER COLUMN cached_label_list DROP NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN campaign_id bigint"
    execute "ALTER TABLE conversations ALTER COLUMN campaign_id DROP NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN contact_id bigint"

    execute "UPDATE conversations c SET contact_id = ci.contact_id FROM contact_inboxes ci WHERE ci.id = c.contact_inbox_id"

    execute "ALTER TABLE conversations ALTER COLUMN contact_id DROP NOT NULL"
    execute "ALTER TABLE conversations ALTER COLUMN contact_inbox_id DROP DEFAULT"

    execute "ALTER TABLE conversations ALTER COLUMN contact_inbox_id TYPE bigint USING (contact_inbox_id)::bigint"

    execute "ALTER TABLE conversations ALTER COLUMN contact_inbox_id DROP NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN contact_last_seen_at timestamp"
    execute "ALTER TABLE conversations ALTER COLUMN contact_last_seen_at DROP NOT NULL"
    execute "ALTER TABLE conversations ALTER COLUMN created_at DROP DEFAULT"

    execute "ALTER TABLE conversations ALTER COLUMN created_at TYPE timestamp USING (created_at)::timestamp"

    execute "ALTER TABLE conversations ALTER COLUMN created_at SET NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN custom_attributes jsonb DEFAULT '{}'::jsonb"
    execute "ALTER TABLE conversations ALTER COLUMN custom_attributes DROP NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN display_id integer"
    execute "UPDATE conversations SET display_id = id"
    execute "ALTER TABLE conversations ALTER COLUMN display_id SET NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN first_reply_created_at timestamp"
    execute "ALTER TABLE conversations ALTER COLUMN first_reply_created_at DROP NOT NULL"
    execute "ALTER TABLE conversations ALTER COLUMN id DROP DEFAULT"
    execute "ALTER TABLE conversations ALTER COLUMN id TYPE integer USING (id)::integer"

    execute "ALTER TABLE conversations ALTER COLUMN id SET DEFAULT nextval('conversations_id_seq'::regclass)"

    execute "ALTER TABLE conversations ALTER COLUMN id SET NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN identifier varchar"
    execute "ALTER TABLE conversations ALTER COLUMN identifier DROP NOT NULL"
    execute "ALTER TABLE conversations ALTER COLUMN inbox_id DROP DEFAULT"

    execute "ALTER TABLE conversations ALTER COLUMN inbox_id TYPE integer USING (inbox_id)::integer"

    execute "ALTER TABLE conversations ALTER COLUMN inbox_id SET NOT NULL"
    execute "ALTER TABLE conversations ALTER COLUMN last_activity_at DROP DEFAULT"

    execute "ALTER TABLE conversations ALTER COLUMN last_activity_at TYPE timestamp USING (last_activity_at)::timestamp"

    execute "ALTER TABLE conversations ALTER COLUMN last_activity_at SET DEFAULT CURRENT_TIMESTAMP"

    execute "UPDATE conversations SET last_activity_at = COALESCE(last_activity_at, created_at)"
    execute "ALTER TABLE conversations ALTER COLUMN last_activity_at SET NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN priority integer"
    execute "ALTER TABLE conversations ALTER COLUMN priority DROP NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN sla_policy_id bigint"
    execute "ALTER TABLE conversations ALTER COLUMN sla_policy_id DROP NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN snoozed_until timestamp"
    execute "ALTER TABLE conversations ALTER COLUMN snoozed_until DROP NOT NULL"

    execute "DO $$ BEGIN IF EXISTS (SELECT 1 FROM conversations WHERE status IS NOT NULL AND status NOT IN ('open','resolved','pending','snoozed')) THEN RAISE EXCEPTION 'Unknown legacy conversations.status enum; migrate its mapping explicitly before continuing'; END IF; END $$"

    execute "ALTER TABLE conversations ALTER COLUMN status DROP DEFAULT"

    execute "ALTER TABLE conversations ALTER COLUMN status TYPE integer USING (CASE status WHEN 'open' THEN 0 WHEN 'resolved' THEN 1 WHEN 'pending' THEN 2 WHEN 'snoozed' THEN 3 ELSE NULL END)::integer"

    execute "ALTER TABLE conversations ALTER COLUMN status SET DEFAULT 0"
    execute "ALTER TABLE conversations ALTER COLUMN status SET NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN status_changed_at timestamp(6)"
    execute "ALTER TABLE conversations ALTER COLUMN status_changed_at DROP NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN team_id bigint"
    execute "ALTER TABLE conversations ALTER COLUMN team_id DROP NOT NULL"
    execute "ALTER TABLE conversations ALTER COLUMN updated_at DROP DEFAULT"

    execute "ALTER TABLE conversations ALTER COLUMN updated_at TYPE timestamp USING (updated_at)::timestamp"

    execute "ALTER TABLE conversations ALTER COLUMN updated_at SET NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN uuid uuid DEFAULT gen_random_uuid()"
    execute "ALTER TABLE conversations ALTER COLUMN uuid SET NOT NULL"
    execute "ALTER TABLE conversations ADD COLUMN waiting_since timestamp(6)"
    execute "ALTER TABLE conversations ALTER COLUMN waiting_since DROP NOT NULL"

    execute "CREATE INDEX conv_acid_inbid_stat_asgnid_idx ON conversations USING btree (account_id, inbox_id, status, assignee_id)"

    execute "CREATE INDEX index_conversations_on_account_id ON conversations USING btree (account_id)"

    execute "CREATE UNIQUE INDEX index_conversations_on_account_id_and_display_id ON conversations USING btree (account_id, display_id)"

    execute "CREATE INDEX index_conversations_on_account_id_status_created_at ON conversations USING btree (account_id, status, created_at)"

    execute "CREATE INDEX index_conversations_on_assignee_id_and_account_id ON conversations USING btree (assignee_id, account_id)"

    execute "CREATE INDEX index_conversations_on_campaign_id ON conversations USING btree (campaign_id)"

    execute "CREATE INDEX index_conversations_on_contact_id ON conversations USING btree (contact_id)"

    execute "CREATE INDEX index_conversations_on_contact_inbox_id ON conversations USING btree (contact_inbox_id)"

    execute "CREATE INDEX index_conversations_on_created_at ON conversations USING btree (created_at)"

    execute "CREATE INDEX index_conversations_on_first_reply_created_at ON conversations USING btree (first_reply_created_at)"

    execute "CREATE INDEX index_conversations_on_id_and_account_id ON conversations USING btree (account_id, id)"

    execute "CREATE INDEX index_conversations_on_identifier_and_account_id ON conversations USING btree (identifier, account_id)"

    execute "CREATE INDEX index_conversations_on_inbox_id ON conversations USING btree (inbox_id)"
    execute "CREATE INDEX index_conversations_on_priority ON conversations USING btree (priority)"

    execute "CREATE INDEX index_conversations_on_status_and_account_id ON conversations USING btree (status, account_id)"

    execute "CREATE INDEX index_conversations_on_status_and_priority ON conversations USING btree (status, priority)"

    execute "CREATE INDEX index_conversations_on_team_id ON conversations USING btree (team_id)"
    execute "CREATE UNIQUE INDEX index_conversations_on_uuid ON conversations USING btree (uuid)"

    execute "CREATE INDEX index_conversations_on_waiting_since ON conversations USING btree (waiting_since)"

    execute "ALTER SEQUENCE conversations_id_seq AS integer"
    execute "ALTER TABLE messages ALTER COLUMN account_id DROP DEFAULT"

    execute "ALTER TABLE messages ALTER COLUMN account_id TYPE integer USING (account_id)::integer"

    execute "ALTER TABLE messages ALTER COLUMN account_id SET NOT NULL"
    execute "ALTER TABLE messages ADD COLUMN additional_attributes jsonb DEFAULT '{}'::jsonb"
    execute "ALTER TABLE messages ALTER COLUMN additional_attributes DROP NOT NULL"
    execute "ALTER TABLE messages ADD COLUMN content_attributes json DEFAULT '{}'::json"
    execute "ALTER TABLE messages ALTER COLUMN content_attributes DROP NOT NULL"

    execute "DO $$ BEGIN IF EXISTS (SELECT 1 FROM messages WHERE content_type IS NOT NULL AND content_type NOT IN ('text','image','audio','video','file','location')) THEN RAISE EXCEPTION 'Unknown legacy messages.content_type enum; migrate its mapping explicitly before continuing'; END IF; END $$"

    execute "ALTER TABLE messages ALTER COLUMN content_type DROP DEFAULT"

    execute "UPDATE messages SET content_attributes = json_build_object('chatwooter_media_type', content_type) WHERE content_type != 'text'"

    execute "ALTER TABLE messages ALTER COLUMN content_type TYPE integer USING (CASE content_type WHEN 'text' THEN 0 WHEN 'image' THEN 0 WHEN 'audio' THEN 0 WHEN 'video' THEN 0 WHEN 'file' THEN 0 WHEN 'location' THEN 0 ELSE NULL END)::integer"

    execute "ALTER TABLE messages ALTER COLUMN content_type SET DEFAULT 0"
    execute "ALTER TABLE messages ALTER COLUMN content_type SET NOT NULL"
    execute "ALTER TABLE messages ALTER COLUMN conversation_id DROP DEFAULT"

    execute "ALTER TABLE messages ALTER COLUMN conversation_id TYPE integer USING (conversation_id)::integer"

    execute "ALTER TABLE messages ALTER COLUMN conversation_id SET NOT NULL"
    execute "ALTER TABLE messages ALTER COLUMN created_at DROP DEFAULT"

    execute "ALTER TABLE messages ALTER COLUMN created_at TYPE timestamp USING (created_at)::timestamp"

    execute "ALTER TABLE messages ALTER COLUMN created_at SET NOT NULL"
    execute "ALTER TABLE messages ADD COLUMN external_source_ids jsonb DEFAULT '{}'::jsonb"
    execute "ALTER TABLE messages ALTER COLUMN external_source_ids DROP NOT NULL"
    execute "ALTER TABLE messages ALTER COLUMN id DROP DEFAULT"
    execute "ALTER TABLE messages ALTER COLUMN id TYPE integer USING (id)::integer"

    execute "ALTER TABLE messages ALTER COLUMN id SET DEFAULT nextval('messages_id_seq'::regclass)"

    execute "ALTER TABLE messages ALTER COLUMN id SET NOT NULL"
    execute "ALTER TABLE messages ALTER COLUMN inbox_id DROP DEFAULT"
    execute "ALTER TABLE messages ALTER COLUMN inbox_id TYPE integer USING (inbox_id)::integer"
    execute "ALTER TABLE messages ALTER COLUMN inbox_id SET NOT NULL"

    execute "DO $$ BEGIN IF EXISTS (SELECT 1 FROM messages WHERE message_type IS NOT NULL AND message_type NOT IN ('incoming','outgoing','activity','template')) THEN RAISE EXCEPTION 'Unknown legacy messages.message_type enum; migrate its mapping explicitly before continuing'; END IF; END $$"

    execute "ALTER TABLE messages ALTER COLUMN message_type DROP DEFAULT"

    execute "ALTER TABLE messages ALTER COLUMN message_type TYPE integer USING (CASE message_type WHEN 'incoming' THEN 0 WHEN 'outgoing' THEN 1 WHEN 'activity' THEN 2 WHEN 'template' THEN 3 ELSE NULL END)::integer"

    execute "ALTER TABLE messages ALTER COLUMN message_type SET NOT NULL"
    execute "ALTER TABLE messages ADD COLUMN processed_message_content text"
    execute "ALTER TABLE messages ALTER COLUMN processed_message_content DROP NOT NULL"
    execute "ALTER TABLE messages ADD COLUMN sender_type varchar"
    execute "ALTER TABLE messages ALTER COLUMN sender_type DROP NOT NULL"
    execute "ALTER TABLE messages ADD COLUMN sentiment jsonb DEFAULT '{}'::jsonb"
    execute "ALTER TABLE messages ALTER COLUMN sentiment DROP NOT NULL"
    execute "ALTER TABLE messages ALTER COLUMN source_id DROP DEFAULT"
    execute "ALTER TABLE messages ALTER COLUMN source_id TYPE text USING (source_id)::text"
    execute "ALTER TABLE messages ALTER COLUMN source_id DROP NOT NULL"

    execute "DO $$ BEGIN IF EXISTS (SELECT 1 FROM messages WHERE status IS NOT NULL AND status NOT IN ('sent','delivered','read','failed')) THEN RAISE EXCEPTION 'Unknown legacy messages.status enum; migrate its mapping explicitly before continuing'; END IF; END $$"

    execute "ALTER TABLE messages ALTER COLUMN status DROP DEFAULT"

    execute "ALTER TABLE messages ALTER COLUMN status TYPE integer USING (CASE status WHEN 'sent' THEN 0 WHEN 'delivered' THEN 1 WHEN 'read' THEN 2 WHEN 'failed' THEN 3 ELSE NULL END)::integer"

    execute "ALTER TABLE messages ALTER COLUMN status SET DEFAULT 0"
    execute "ALTER TABLE messages ALTER COLUMN status DROP NOT NULL"
    execute "ALTER TABLE messages ALTER COLUMN updated_at DROP DEFAULT"

    execute "ALTER TABLE messages ALTER COLUMN updated_at TYPE timestamp USING (updated_at)::timestamp"

    execute "ALTER TABLE messages ALTER COLUMN updated_at SET NOT NULL"

    execute "CREATE INDEX idx_messages_account_content_created ON messages USING btree (account_id, content_type, created_at)"

    execute "CREATE INDEX index_messages_on_account_created_type ON messages USING btree (account_id, created_at, message_type)"

    execute "CREATE INDEX index_messages_on_account_id ON messages USING btree (account_id)"

    execute "CREATE INDEX index_messages_on_account_id_and_inbox_id ON messages USING btree (account_id, inbox_id)"

    execute "CREATE INDEX index_messages_on_additional_attributes_campaign_id ON messages USING gin (((additional_attributes -> 'campaign_id'::text)))"

    execute "CREATE INDEX index_messages_on_content ON messages USING gin (content gin_trgm_ops)"

    execute "CREATE INDEX index_messages_on_conversation_account_type_created ON messages USING btree (conversation_id, account_id, message_type, created_at)"

    execute "CREATE INDEX index_messages_on_conversation_id ON messages USING btree (conversation_id)"

    execute "CREATE INDEX index_messages_on_created_at ON messages USING btree (created_at)"
    execute "CREATE INDEX index_messages_on_inbox_id ON messages USING btree (inbox_id)"

    execute "CREATE INDEX index_messages_on_sender_and_created ON messages USING btree (sender_type, sender_id, created_at)"

    execute "CREATE INDEX index_messages_on_sender_type_and_sender_id ON messages USING btree (sender_type, sender_id)"

    execute "CREATE INDEX index_messages_on_source_id ON messages USING btree (source_id)"
    execute "ALTER SEQUENCE messages_id_seq AS integer"
    execute "ALTER TABLE attachments ADD COLUMN account_id integer"

    execute "UPDATE attachments a SET account_id = m.account_id FROM messages m WHERE m.id = a.message_id"

    execute "ALTER TABLE attachments ALTER COLUMN account_id SET NOT NULL"
    execute "ALTER TABLE attachments ADD COLUMN coordinates_lat double precision DEFAULT 0.0"
    execute "ALTER TABLE attachments ALTER COLUMN coordinates_lat DROP NOT NULL"
    execute "ALTER TABLE attachments ADD COLUMN coordinates_long double precision DEFAULT 0.0"
    execute "ALTER TABLE attachments ALTER COLUMN coordinates_long DROP NOT NULL"
    execute "ALTER TABLE attachments ALTER COLUMN created_at DROP DEFAULT"

    execute "ALTER TABLE attachments ALTER COLUMN created_at TYPE timestamp USING (created_at)::timestamp"

    execute "ALTER TABLE attachments ALTER COLUMN created_at SET NOT NULL"
    execute "ALTER TABLE attachments ADD COLUMN extension varchar"
    execute "ALTER TABLE attachments ALTER COLUMN extension DROP NOT NULL"
    execute "ALTER TABLE attachments ADD COLUMN external_url varchar"
    execute "ALTER TABLE attachments ALTER COLUMN external_url DROP NOT NULL"
    execute "ALTER TABLE attachments ADD COLUMN fallback_title varchar"
    execute "ALTER TABLE attachments ALTER COLUMN fallback_title DROP NOT NULL"

    execute "DO $$ BEGIN IF EXISTS (SELECT 1 FROM attachments WHERE file_type IS NOT NULL AND file_type NOT IN ('image','audio','video','file','location','fallback','share','story_mention','contact','ig_reel','ig_post','ig_story','embed')) THEN RAISE EXCEPTION 'Unknown legacy attachments.file_type enum; migrate its mapping explicitly before continuing'; END IF; END $$"

    execute "ALTER TABLE attachments ALTER COLUMN file_type DROP DEFAULT"

    execute "ALTER TABLE attachments ALTER COLUMN file_type TYPE integer USING (CASE file_type WHEN 'image' THEN 0 WHEN 'audio' THEN 1 WHEN 'video' THEN 2 WHEN 'file' THEN 3 WHEN 'location' THEN 4 WHEN 'fallback' THEN 5 WHEN 'share' THEN 6 WHEN 'story_mention' THEN 7 WHEN 'contact' THEN 8 WHEN 'ig_reel' THEN 9 WHEN 'ig_post' THEN 10 WHEN 'ig_story' THEN 11 WHEN 'embed' THEN 12 ELSE NULL END)::integer"

    execute "ALTER TABLE attachments ALTER COLUMN file_type SET DEFAULT 0"
    execute "ALTER TABLE attachments ALTER COLUMN file_type DROP NOT NULL"
    execute "ALTER TABLE attachments ALTER COLUMN id DROP DEFAULT"
    execute "ALTER TABLE attachments ALTER COLUMN id TYPE integer USING (id)::integer"

    execute "ALTER TABLE attachments ALTER COLUMN id SET DEFAULT nextval('attachments_id_seq'::regclass)"

    execute "ALTER TABLE attachments ALTER COLUMN id SET NOT NULL"
    execute "ALTER TABLE attachments ALTER COLUMN message_id DROP DEFAULT"

    execute "ALTER TABLE attachments ALTER COLUMN message_id TYPE integer USING (message_id)::integer"

    execute "ALTER TABLE attachments ALTER COLUMN message_id SET NOT NULL"
    execute "ALTER TABLE attachments ADD COLUMN meta jsonb DEFAULT '{}'::jsonb"
    execute "ALTER TABLE attachments ALTER COLUMN meta DROP NOT NULL"
    execute "ALTER TABLE attachments ALTER COLUMN updated_at DROP DEFAULT"

    execute "ALTER TABLE attachments ALTER COLUMN updated_at TYPE timestamp USING (updated_at)::timestamp"

    execute "ALTER TABLE attachments ALTER COLUMN updated_at SET NOT NULL"
    execute "CREATE INDEX index_attachments_on_account_id ON attachments USING btree (account_id)"
    execute "CREATE INDEX index_attachments_on_message_id ON attachments USING btree (message_id)"
    execute "ALTER SEQUENCE attachments_id_seq AS integer"
  end

  def down do
    raise "Core parity migration requires restoring the pre-migration database backup"
  end
end
