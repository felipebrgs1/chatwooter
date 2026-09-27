defmodule Chatwooter.Repo.Migrations.AlignInboxesAndMembershipsWithUpstream do
  use Ecto.Migration

  def up do
    execute("ALTER SEQUENCE inboxes_id_seq AS integer")

    execute("""
    CREATE TABLE chatwooter_inbox_configs (inbox_id integer PRIMARY KEY, provider_config jsonb NOT NULL DEFAULT '{}'::jsonb)
    """)

    execute("""
    INSERT INTO chatwooter_inbox_configs SELECT id, provider_config FROM inboxes
    """)

    execute("""
    ALTER TABLE inboxes RENAME COLUMN inserted_at TO created_at
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN channel_id integer
    """)

    execute("""
    DO $$ DECLARE i record; cid integer; BEGIN
    FOR i IN SELECT * FROM inboxes LOOP
    IF i.channel_type = 'telegram' THEN
    INSERT INTO channel_telegram(account_id, bot_token, created_at, updated_at)
    VALUES(i.account_id, COALESCE(NULLIF(i.provider_config->>'bot_token', ''), 'chatwooter-unconfigured-' || i.id), i.created_at, i.updated_at)
    ON CONFLICT(bot_token) DO UPDATE SET bot_token = EXCLUDED.bot_token RETURNING id INTO cid;
    ELSIF i.channel_type = 'whatsapp' THEN
    INSERT INTO channel_whatsapp(account_id,phone_number,provider,provider_config,created_at,updated_at)
    VALUES(i.account_id,'chatwooter-unconfigured-' || i.id,'default',i.provider_config,i.created_at,i.updated_at)
    ON CONFLICT(phone_number) DO UPDATE SET phone_number=EXCLUDED.phone_number RETURNING id INTO cid;
    ELSE RAISE EXCEPTION 'Unsupported local inbox channel: %',i.channel_type;
    END IF;
    UPDATE inboxes SET channel_id=cid WHERE id=i.id;
    END LOOP; END $$
    """)

    execute("""
    UPDATE inboxes SET channel_type = CASE channel_type WHEN 'telegram' THEN 'Channel::Telegram' WHEN 'whatsapp' THEN 'Channel::Whatsapp' END
    """)

    execute("""
    ALTER TABLE inboxes DROP CONSTRAINT inboxes_account_id_fkey
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN account_id TYPE integer USING account_id::integer
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN account_id DROP DEFAULT
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN account_id SET NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN allow_messages_after_resolved boolean DEFAULT true
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN allow_messages_after_resolved SET DEFAULT true
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN allow_messages_after_resolved DROP NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN auto_assignment_config jsonb DEFAULT '{}'::jsonb
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN auto_assignment_config SET DEFAULT '{}'::jsonb
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN auto_assignment_config DROP NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN business_name character varying
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN business_name DROP DEFAULT
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN business_name DROP NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN channel_id DROP DEFAULT
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN channel_id SET NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN channel_type TYPE character varying USING channel_type::character varying
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN channel_type DROP DEFAULT
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN channel_type DROP NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN created_at DROP DEFAULT
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN created_at SET NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN csat_config jsonb DEFAULT '{}'::jsonb
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN csat_config SET DEFAULT '{}'::jsonb
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN csat_config SET NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN csat_survey_enabled boolean DEFAULT false
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN csat_survey_enabled SET DEFAULT false
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN csat_survey_enabled DROP NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN email_address character varying
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN email_address DROP DEFAULT
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN email_address DROP NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN enable_auto_assignment boolean DEFAULT true
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN enable_auto_assignment SET DEFAULT true
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN enable_auto_assignment DROP NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN enable_email_collect boolean DEFAULT true
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN enable_email_collect SET DEFAULT true
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN enable_email_collect DROP NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN greeting_enabled boolean DEFAULT false
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN greeting_enabled SET DEFAULT false
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN greeting_enabled DROP NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN greeting_message TYPE character varying USING greeting_message::character varying
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN greeting_message DROP DEFAULT
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN greeting_message DROP NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN id TYPE integer USING id::integer
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN id DROP DEFAULT
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN id SET NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN lock_to_single_conversation boolean DEFAULT false
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN lock_to_single_conversation SET DEFAULT false
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN lock_to_single_conversation SET NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN name TYPE character varying USING name::character varying
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN name DROP DEFAULT
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN name SET NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN out_of_office_message character varying
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN out_of_office_message DROP DEFAULT
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN out_of_office_message DROP NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN sender_name_type integer DEFAULT 0
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN sender_name_type SET DEFAULT 0
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN sender_name_type SET NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN timezone character varying DEFAULT 'UTC'
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN timezone SET DEFAULT 'UTC'
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN timezone DROP NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN updated_at TYPE timestamp without time zone USING updated_at::timestamp without time zone
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN updated_at DROP DEFAULT
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN updated_at SET NOT NULL
    """)

    execute("""
    ALTER TABLE inboxes ADD COLUMN working_hours_enabled boolean DEFAULT false
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN working_hours_enabled SET DEFAULT false
    """)

    execute("""
    ALTER TABLE inboxes ALTER COLUMN working_hours_enabled DROP NOT NULL
    """)

    execute("""
    DROP INDEX inboxes_account_id_index
    """)

    execute("""
    CREATE INDEX index_inboxes_on_account_id ON inboxes (account_id)
    """)

    execute("""
    CREATE INDEX index_inboxes_on_channel_id_and_channel_type ON inboxes (channel_id, channel_type)
    """)

    execute("""
    ALTER TABLE inbox_members DROP CONSTRAINT inbox_members_inbox_id_fkey
    """)

    execute("""
    ALTER TABLE inbox_members DROP CONSTRAINT inbox_members_user_id_fkey
    """)

    execute("""
    ALTER TABLE inbox_members ALTER COLUMN inbox_id TYPE integer USING inbox_id::integer
    """)

    execute("""
    ALTER TABLE inbox_members ALTER COLUMN inbox_id DROP DEFAULT
    """)

    execute("""
    ALTER TABLE inbox_members ALTER COLUMN inbox_id SET NOT NULL
    """)

    execute("""
    ALTER TABLE inbox_members ALTER COLUMN user_id TYPE integer USING user_id::integer
    """)

    execute("""
    ALTER TABLE inbox_members ALTER COLUMN user_id DROP DEFAULT
    """)

    execute("""
    ALTER TABLE inbox_members ALTER COLUMN user_id SET NOT NULL
    """)

    execute("""
    ALTER TABLE teams DROP CONSTRAINT teams_account_id_fkey
    """)

    execute("""
    ALTER TABLE teams ALTER COLUMN icon TYPE character varying USING icon::character varying
    """)

    execute("""
    ALTER TABLE teams ALTER COLUMN icon SET DEFAULT ''
    """)

    execute("""
    ALTER TABLE teams ALTER COLUMN icon DROP NOT NULL
    """)

    execute("""
    ALTER TABLE teams ALTER COLUMN icon_color TYPE character varying USING icon_color::character varying
    """)

    execute("""
    ALTER TABLE teams ALTER COLUMN icon_color SET DEFAULT ''
    """)

    execute("""
    ALTER TABLE teams ALTER COLUMN icon_color DROP NOT NULL
    """)

    execute("""
    ALTER TABLE teams ALTER COLUMN name TYPE character varying USING name::character varying
    """)

    execute("""
    ALTER TABLE teams ALTER COLUMN name DROP DEFAULT
    """)

    execute("""
    ALTER TABLE teams ALTER COLUMN name SET NOT NULL
    """)

    execute("""
    ALTER TABLE team_members DROP CONSTRAINT team_members_team_id_fkey
    """)

    execute("""
    ALTER TABLE team_members DROP CONSTRAINT team_members_user_id_fkey
    """)

    execute("""
    ALTER TABLE inboxes DROP COLUMN provider_config
    """)
  end

  def down do
    raise Ecto.MigrationError,
      message:
        "Restore a pre-migration backup to reverse inbox parity without losing restored data."
  end
end
