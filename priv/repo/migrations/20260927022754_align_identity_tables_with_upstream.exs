defmodule Chatwooter.Repo.Migrations.AlignIdentityTablesWithUpstream do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE account_users DROP CONSTRAINT account_users_account_id_fkey, DROP CONSTRAINT account_users_user_id_fkey"
    execute "ALTER TABLE accounts RENAME COLUMN inserted_at TO created_at"
    execute "DROP INDEX users_email_index"
    execute "ALTER TABLE users RENAME COLUMN inserted_at TO created_at"
    execute "DROP INDEX account_users_account_id_availability_index"
    execute "DROP INDEX account_users_account_id_user_id_index"
    execute "DROP INDEX account_users_user_id_index"
    execute "ALTER TABLE account_users RENAME COLUMN inserted_at TO created_at"
    execute "ALTER TABLE users RENAME COLUMN hashed_password TO encrypted_password"

    execute "DO $$ BEGIN IF EXISTS (SELECT 1 FROM accounts WHERE locale IS NOT NULL AND (CASE locale WHEN 'en' THEN 0 WHEN 'ar' THEN 1 WHEN 'nl' THEN 2 WHEN 'fr' THEN 3 WHEN 'de' THEN 4 WHEN 'hi' THEN 5 WHEN 'it' THEN 6 WHEN 'ja' THEN 7 WHEN 'ko' THEN 8 WHEN 'pt' THEN 9 WHEN 'ru' THEN 10 WHEN 'zh' THEN 11 WHEN 'es' THEN 12 WHEN 'ml' THEN 13 WHEN 'ca' THEN 14 WHEN 'el' THEN 15 WHEN 'pt_BR' THEN 16 WHEN 'ro' THEN 17 WHEN 'ta' THEN 18 WHEN 'fa' THEN 19 WHEN 'zh_TW' THEN 20 WHEN 'vi' THEN 21 WHEN 'da' THEN 22 WHEN 'tr' THEN 23 WHEN 'cs' THEN 24 WHEN 'fi' THEN 25 WHEN 'id' THEN 26 WHEN 'sv' THEN 27 WHEN 'hu' THEN 28 WHEN 'no' THEN 29 WHEN 'zh_CN' THEN 30 WHEN 'pl' THEN 31 WHEN 'sk' THEN 32 WHEN 'uk' THEN 33 WHEN 'th' THEN 34 WHEN 'lv' THEN 35 WHEN 'is' THEN 36 WHEN 'he' THEN 37 WHEN 'lt' THEN 38 WHEN 'sr' THEN 39 WHEN 'bg' THEN 40 WHEN 'et' THEN 41 WHEN 'uz' THEN 42 WHEN 'sl' THEN 43 WHEN 'pt-BR' THEN 16 WHEN 'zh-TW' THEN 20 WHEN 'zh-CN' THEN 30 END) IS NULL) THEN RAISE EXCEPTION 'Unknown locale; map explicitly before schema alignment'; END IF; END $$"

    execute "DO $$ BEGIN IF EXISTS (SELECT 1 FROM account_users WHERE role IS NOT NULL AND (CASE role WHEN 'agent' THEN 0 WHEN 'admin' THEN 1 END) IS NULL) THEN RAISE EXCEPTION 'Unknown membership role; map explicitly before schema alignment'; END IF; END $$"

    execute "DO $$ BEGIN IF EXISTS (SELECT 1 FROM account_users WHERE availability IS NOT NULL AND (CASE availability WHEN 'online' THEN 0 WHEN 'offline' THEN 1 WHEN 'busy' THEN 2 END) IS NULL) THEN RAISE EXCEPTION 'Unknown membership availability; map explicitly before schema alignment'; END IF; END $$"

    execute "UPDATE users SET name = split_part(email::text, '@', 1) WHERE name IS NULL"
    execute "UPDATE users SET encrypted_password = '' WHERE encrypted_password IS NULL"
    execute "ALTER TABLE accounts ADD COLUMN auto_resolve_duration integer"
    execute "ALTER TABLE accounts ALTER COLUMN created_at DROP DEFAULT"
    execute "ALTER TABLE accounts ALTER COLUMN created_at TYPE timestamp without time zone"
    execute "ALTER TABLE accounts ALTER COLUMN created_at SET NOT NULL"
    execute "ALTER TABLE accounts ADD COLUMN custom_attributes jsonb DEFAULT '{}'::jsonb"
    execute "ALTER TABLE accounts ADD COLUMN domain varchar(100)"
    execute "ALTER TABLE accounts ADD COLUMN feature_flags bigint DEFAULT 0 NOT NULL"
    execute "ALTER TABLE accounts ADD COLUMN feature_flags_ext_1 bigint DEFAULT 0 NOT NULL"
    execute "ALTER TABLE accounts ALTER COLUMN id TYPE integer"
    execute "ALTER SEQUENCE accounts_id_seq AS integer"

    execute "ALTER TABLE accounts ADD COLUMN internal_attributes jsonb DEFAULT '{}'::jsonb NOT NULL"

    execute "ALTER TABLE accounts ADD COLUMN limits jsonb DEFAULT '{}'::jsonb"
    execute "ALTER TABLE accounts ALTER COLUMN locale DROP DEFAULT"

    execute "ALTER TABLE accounts ALTER COLUMN locale TYPE integer USING CASE locale WHEN 'en' THEN 0 WHEN 'ar' THEN 1 WHEN 'nl' THEN 2 WHEN 'fr' THEN 3 WHEN 'de' THEN 4 WHEN 'hi' THEN 5 WHEN 'it' THEN 6 WHEN 'ja' THEN 7 WHEN 'ko' THEN 8 WHEN 'pt' THEN 9 WHEN 'ru' THEN 10 WHEN 'zh' THEN 11 WHEN 'es' THEN 12 WHEN 'ml' THEN 13 WHEN 'ca' THEN 14 WHEN 'el' THEN 15 WHEN 'pt_BR' THEN 16 WHEN 'ro' THEN 17 WHEN 'ta' THEN 18 WHEN 'fa' THEN 19 WHEN 'zh_TW' THEN 20 WHEN 'vi' THEN 21 WHEN 'da' THEN 22 WHEN 'tr' THEN 23 WHEN 'cs' THEN 24 WHEN 'fi' THEN 25 WHEN 'id' THEN 26 WHEN 'sv' THEN 27 WHEN 'hu' THEN 28 WHEN 'no' THEN 29 WHEN 'zh_CN' THEN 30 WHEN 'pl' THEN 31 WHEN 'sk' THEN 32 WHEN 'uk' THEN 33 WHEN 'th' THEN 34 WHEN 'lv' THEN 35 WHEN 'is' THEN 36 WHEN 'he' THEN 37 WHEN 'lt' THEN 38 WHEN 'sr' THEN 39 WHEN 'bg' THEN 40 WHEN 'et' THEN 41 WHEN 'uz' THEN 42 WHEN 'sl' THEN 43 WHEN 'pt-BR' THEN 16 WHEN 'zh-TW' THEN 20 WHEN 'zh-CN' THEN 30 END"

    execute "ALTER TABLE accounts ALTER COLUMN locale DROP NOT NULL"
    execute "ALTER TABLE accounts ALTER COLUMN locale SET DEFAULT 0"
    execute "ALTER TABLE accounts ALTER COLUMN name DROP DEFAULT"
    execute "ALTER TABLE accounts ALTER COLUMN name TYPE varchar"
    execute "ALTER TABLE accounts ALTER COLUMN name SET NOT NULL"
    execute "ALTER TABLE accounts ALTER COLUMN settings DROP DEFAULT"
    execute "ALTER TABLE accounts ALTER COLUMN settings TYPE jsonb"
    execute "ALTER TABLE accounts ALTER COLUMN settings DROP NOT NULL"
    execute "ALTER TABLE accounts ALTER COLUMN settings SET DEFAULT '{}'::jsonb"
    execute "ALTER TABLE accounts ADD COLUMN status integer DEFAULT 0"
    execute "ALTER TABLE accounts ADD COLUMN support_email varchar(100)"
    execute "ALTER TABLE accounts ALTER COLUMN updated_at DROP DEFAULT"
    execute "ALTER TABLE accounts ALTER COLUMN updated_at TYPE timestamp without time zone"
    execute "ALTER TABLE accounts ALTER COLUMN updated_at SET NOT NULL"
    create index(:accounts, [:status], name: :index_accounts_on_status)
    execute "ALTER TABLE users ADD COLUMN last_sign_in_at timestamp without time zone"
    execute "ALTER TABLE users ADD COLUMN current_sign_in_at timestamp without time zone"
    execute "ALTER TABLE users ALTER COLUMN confirmed_at DROP DEFAULT"
    execute "ALTER TABLE users ALTER COLUMN confirmed_at TYPE timestamp without time zone"
    execute "ALTER TABLE users ALTER COLUMN confirmed_at DROP NOT NULL"
    execute "ALTER TABLE users ADD COLUMN reset_password_sent_at timestamp without time zone"
    execute "ALTER TABLE users ALTER COLUMN encrypted_password DROP DEFAULT"
    execute "ALTER TABLE users ALTER COLUMN encrypted_password TYPE varchar"
    execute "ALTER TABLE users ALTER COLUMN encrypted_password SET NOT NULL"
    execute "ALTER TABLE users ALTER COLUMN encrypted_password SET DEFAULT ''"
    execute "ALTER TABLE users ALTER COLUMN updated_at DROP DEFAULT"
    execute "ALTER TABLE users ALTER COLUMN updated_at TYPE timestamp without time zone"
    execute "ALTER TABLE users ALTER COLUMN updated_at SET NOT NULL"
    execute "ALTER TABLE users ADD COLUMN sign_in_count integer DEFAULT 0 NOT NULL"
    execute "ALTER TABLE users ADD COLUMN reset_password_token varchar"
    execute "ALTER TABLE users ADD COLUMN uid varchar DEFAULT '' NOT NULL"
    execute "ALTER TABLE users ADD COLUMN otp_required_for_login boolean DEFAULT false"
    execute "ALTER TABLE users ALTER COLUMN created_at DROP DEFAULT"
    execute "ALTER TABLE users ALTER COLUMN created_at TYPE timestamp without time zone"
    execute "ALTER TABLE users ALTER COLUMN created_at SET NOT NULL"
    execute "ALTER TABLE users ADD COLUMN display_name varchar"
    execute "ALTER TABLE users ALTER COLUMN name DROP DEFAULT"
    execute "ALTER TABLE users ALTER COLUMN name TYPE varchar"
    execute "ALTER TABLE users ALTER COLUMN name SET NOT NULL"
    execute "ALTER TABLE users ADD COLUMN consumed_timestep integer"
    execute "ALTER TABLE users ALTER COLUMN email DROP DEFAULT"
    execute "ALTER TABLE users ALTER COLUMN email TYPE varchar"
    execute "ALTER TABLE users ALTER COLUMN email DROP NOT NULL"
    execute "ALTER TABLE users ADD COLUMN current_sign_in_ip varchar"
    execute "ALTER TABLE users ADD COLUMN type varchar"
    execute "ALTER TABLE users ADD COLUMN custom_attributes jsonb DEFAULT '{}'::jsonb"
    execute "ALTER TABLE users ADD COLUMN last_sign_in_ip varchar"
    execute "ALTER TABLE users ADD COLUMN pubsub_token varchar"
    execute "ALTER TABLE users ADD COLUMN tokens json"
    execute "ALTER TABLE users ADD COLUMN availability integer DEFAULT 0"
    execute "ALTER TABLE users ADD COLUMN otp_backup_codes text"
    execute "ALTER TABLE users ADD COLUMN otp_secret varchar"
    execute "ALTER TABLE users ADD COLUMN confirmation_sent_at timestamp without time zone"
    execute "ALTER TABLE users ADD COLUMN device_trust_version integer DEFAULT 0 NOT NULL"
    execute "ALTER TABLE users ADD COLUMN ui_settings jsonb DEFAULT '{}'::jsonb"
    execute "ALTER TABLE users ALTER COLUMN id TYPE integer"
    execute "ALTER SEQUENCE users_id_seq AS integer"
    execute "ALTER TABLE users ADD COLUMN confirmation_token varchar"
    execute "ALTER TABLE users ADD COLUMN message_signature text"
    execute "ALTER TABLE users ADD COLUMN remember_created_at timestamp without time zone"
    execute "ALTER TABLE users ADD COLUMN unconfirmed_email varchar"
    execute "ALTER TABLE users ADD COLUMN provider varchar DEFAULT 'email' NOT NULL"
    execute "UPDATE users SET uid = lower(email)"
    create index(:users, [:email], name: :index_users_on_email)
    create index(:users, [:otp_required_for_login], name: :index_users_on_otp_required_for_login)
    create unique_index(:users, [:otp_secret], name: :index_users_on_otp_secret)
    create unique_index(:users, [:pubsub_token], name: :index_users_on_pubsub_token)

    create unique_index(:users, [:reset_password_token],
             name: :index_users_on_reset_password_token
           )

    create unique_index(:users, [:uid, :provider], name: :index_users_on_uid_and_provider)
    execute "ALTER TABLE account_users ALTER COLUMN account_id DROP DEFAULT"
    execute "ALTER TABLE account_users ALTER COLUMN account_id TYPE bigint"
    execute "ALTER TABLE account_users ALTER COLUMN account_id DROP NOT NULL"
    execute "ALTER TABLE account_users ADD COLUMN active_at timestamp without time zone"
    execute "ALTER TABLE account_users ADD COLUMN agent_capacity_policy_id bigint"
    execute "ALTER TABLE account_users ALTER COLUMN auto_offline DROP DEFAULT"
    execute "ALTER TABLE account_users ALTER COLUMN auto_offline TYPE boolean"
    execute "ALTER TABLE account_users ALTER COLUMN auto_offline SET NOT NULL"
    execute "ALTER TABLE account_users ALTER COLUMN auto_offline SET DEFAULT true"
    execute "ALTER TABLE account_users ALTER COLUMN availability DROP DEFAULT"

    execute "ALTER TABLE account_users ALTER COLUMN availability TYPE integer USING CASE availability WHEN 'online' THEN 0 WHEN 'offline' THEN 1 WHEN 'busy' THEN 2 END"

    execute "ALTER TABLE account_users ALTER COLUMN availability SET NOT NULL"
    execute "ALTER TABLE account_users ALTER COLUMN availability SET DEFAULT 0"
    execute "ALTER TABLE account_users ALTER COLUMN created_at DROP DEFAULT"

    execute "ALTER TABLE account_users ALTER COLUMN created_at TYPE timestamp(6) without time zone"

    execute "ALTER TABLE account_users ALTER COLUMN created_at SET NOT NULL"
    execute "ALTER TABLE account_users ADD COLUMN custom_role_id bigint"
    execute "ALTER TABLE account_users ADD COLUMN inviter_id bigint"
    execute "ALTER TABLE account_users ALTER COLUMN role DROP DEFAULT"

    execute "ALTER TABLE account_users ALTER COLUMN role TYPE integer USING CASE role WHEN 'agent' THEN 0 WHEN 'admin' THEN 1 END"

    execute "ALTER TABLE account_users ALTER COLUMN role DROP NOT NULL"
    execute "ALTER TABLE account_users ALTER COLUMN role SET DEFAULT 0"
    execute "ALTER TABLE account_users ALTER COLUMN updated_at DROP DEFAULT"

    execute "ALTER TABLE account_users ALTER COLUMN updated_at TYPE timestamp(6) without time zone"

    execute "ALTER TABLE account_users ALTER COLUMN updated_at SET NOT NULL"
    execute "ALTER TABLE account_users ALTER COLUMN user_id DROP DEFAULT"
    execute "ALTER TABLE account_users ALTER COLUMN user_id TYPE bigint"
    execute "ALTER TABLE account_users ALTER COLUMN user_id DROP NOT NULL"

    create unique_index(:account_users, [:account_id, :user_id],
             name: :uniq_user_id_per_account_id
           )

    create index(:account_users, [:account_id], name: :index_account_users_on_account_id)

    create index(:account_users, [:agent_capacity_policy_id],
             name: :index_account_users_on_agent_capacity_policy_id
           )

    create index(:account_users, [:custom_role_id], name: :index_account_users_on_custom_role_id)
    create index(:account_users, [:user_id], name: :index_account_users_on_user_id)
  end

  def down do
    raise "Identity alignment cannot discard restored columns; restore the pre-migration backup instead"
  end
end
