defmodule Chatwooter.Repo.Migrations.CreateCampaignParityTables do
  use Ecto.Migration

  def up do
    create table(:campaigns) do
      add :display_id, :integer, null: false
      add :title, :varchar, null: false
      add :description, :text
      add :message, :text, null: false
      add :sender_id, :integer
      add :enabled, :boolean, default: true
      add :account_id, :bigint, null: false
      add :inbox_id, :bigint, null: false
      add :trigger_rules, :jsonb, default: fragment("'{}'::jsonb")
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :campaign_type, :integer, default: 0, null: false
      add :campaign_status, :integer, default: 0, null: false
      add :audience, :jsonb, default: fragment("'[]'::jsonb")
      add :scheduled_at, :timestamp
      add :trigger_only_during_business_hours, :boolean, default: false
      add :template_params, :jsonb
      add :started_at, :"timestamp(6)"
      add :completed_at, :"timestamp(6)"
    end

    create index(:campaigns, [:account_id], name: :index_campaigns_on_account_id)
    create index(:campaigns, [:campaign_status], name: :index_campaigns_on_campaign_status)
    create index(:campaigns, [:campaign_type], name: :index_campaigns_on_campaign_type)
    create index(:campaigns, [:inbox_id], name: :index_campaigns_on_inbox_id)
    create index(:campaigns, [:scheduled_at], name: :index_campaigns_on_scheduled_at)

    create table(:campaign_recipients) do
      add :account_id, references(:accounts, type: :bigint, on_delete: :delete_all), null: false

      add :campaign_id, references(:campaigns, type: :bigint, on_delete: :delete_all), null: false

      add :contact_id, references(:contacts, type: :bigint, on_delete: :delete_all), null: false

      add :inbox_id, references(:inboxes, type: :bigint, on_delete: :delete_all), null: false

      add :source_id, :varchar
      add :status, :integer, default: 0, null: false
      add :error_code, :varchar
      add :error_title, :varchar
      add :error_message, :text
      add :message_content, :text
      add :sent_at, :"timestamp(6)"
      add :delivered_at, :"timestamp(6)"
      add :read_at, :"timestamp(6)"
      add :failed_at, :"timestamp(6)"
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:campaign_recipients, [:account_id, :campaign_id],
             name: :index_campaign_recipients_on_account_id_and_campaign_id
           )

    create index(:campaign_recipients, [:account_id],
             name: :index_campaign_recipients_on_account_id
           )

    create unique_index(:campaign_recipients, [:campaign_id, :contact_id],
             name: :index_campaign_recipients_on_campaign_id_and_contact_id
           )

    create index(:campaign_recipients, [:campaign_id, :status],
             name: :index_campaign_recipients_on_campaign_id_and_status
           )

    create index(:campaign_recipients, [:campaign_id],
             name: :index_campaign_recipients_on_campaign_id
           )

    create index(:campaign_recipients, [:contact_id],
             name: :index_campaign_recipients_on_contact_id
           )

    create index(:campaign_recipients, [:inbox_id], name: :index_campaign_recipients_on_inbox_id)

    create unique_index(:campaign_recipients, [:source_id],
             name: :index_campaign_recipients_on_source_id,
             where: "(source_id IS NOT NULL)"
           )

    # Replicates the upstream per-account campaign display_id sequence. The
    # BEFORE trigger only fills NULL values so explicitly restored rows keep
    # their display_id (pg_restore COPY never fires triggers either).
    execute("""
    CREATE OR REPLACE FUNCTION chatwooter_assign_camp_dpid() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      IF NEW.display_id IS NULL THEN
        NEW.display_id := nextval('camp_dpid_seq_' || NEW.account_id);
      END IF;
      RETURN NEW;
    END;
    $$;
    """)

    execute("""
    CREATE TRIGGER campaigns_before_insert_row_tr
    BEFORE INSERT ON campaigns
    FOR EACH ROW EXECUTE FUNCTION chatwooter_assign_camp_dpid();
    """)

    execute("""
    DO $$ DECLARE account record; BEGIN
      FOR account IN SELECT id FROM accounts LOOP
        EXECUTE format('CREATE SEQUENCE IF NOT EXISTS camp_dpid_seq_%s', account.id);
      END LOOP;
    END $$;
    """)
  end

  # Per-account camp_dpid_seq_* sequences are intentionally kept: dropping
  # them would reset campaign numbering after a re-migration.
  def down do
    execute("DROP TRIGGER IF EXISTS campaigns_before_insert_row_tr ON campaigns")
    execute("DROP FUNCTION IF EXISTS chatwooter_assign_camp_dpid()")
    drop table(:campaign_recipients)
    drop table(:campaigns)
  end
end
