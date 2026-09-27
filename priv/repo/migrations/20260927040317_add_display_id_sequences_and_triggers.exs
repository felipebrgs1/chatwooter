defmodule Chatwooter.Repo.Migrations.AddDisplayIdSequencesAndTriggers do
  use Ecto.Migration

  # Replicates the upstream per-account display_id sequences. The BEFORE
  # trigger only fills NULL values so explicitly restored rows keep their
  # display_id (pg_restore COPY never fires triggers either).
  def up do
    execute("""
    CREATE OR REPLACE FUNCTION chatwooter_create_conv_dpid_seq() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      EXECUTE format('CREATE SEQUENCE IF NOT EXISTS conv_dpid_seq_%s', NEW.id);
      RETURN NEW;
    END;
    $$;
    """)

    execute("""
    CREATE TRIGGER accounts_after_insert_row_tr
    AFTER INSERT ON accounts
    FOR EACH ROW EXECUTE FUNCTION chatwooter_create_conv_dpid_seq();
    """)

    execute("""
    CREATE OR REPLACE FUNCTION chatwooter_assign_conv_dpid() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      IF NEW.display_id IS NULL THEN
        NEW.display_id := nextval('conv_dpid_seq_' || NEW.account_id);
      END IF;
      RETURN NEW;
    END;
    $$;
    """)

    execute("""
    CREATE TRIGGER conversations_before_insert_row_tr
    BEFORE INSERT ON conversations
    FOR EACH ROW EXECUTE FUNCTION chatwooter_assign_conv_dpid();
    """)

    execute("""
    CREATE OR REPLACE FUNCTION chatwooter_create_camp_dpid_seq() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      EXECUTE format('CREATE SEQUENCE IF NOT EXISTS camp_dpid_seq_%s', NEW.id);
      RETURN NEW;
    END;
    $$;
    """)

    execute("""
    CREATE TRIGGER camp_dpid_before_insert
    AFTER INSERT ON accounts
    FOR EACH ROW EXECUTE FUNCTION chatwooter_create_camp_dpid_seq();
    """)

    execute("""
    DO $$ DECLARE account record; peak integer; BEGIN
      FOR account IN SELECT id FROM accounts LOOP
        EXECUTE format('CREATE SEQUENCE IF NOT EXISTS conv_dpid_seq_%s', account.id);
        EXECUTE format('CREATE SEQUENCE IF NOT EXISTS camp_dpid_seq_%s', account.id);
        SELECT max(display_id) INTO peak FROM conversations WHERE account_id = account.id;
        IF peak IS NOT NULL THEN
          PERFORM setval('conv_dpid_seq_' || account.id, peak);
        END IF;
      END LOOP;
    END $$;
    """)
  end

  def down do
    raise Ecto.MigrationError,
      message:
        "Display_id sequences back conversation ordering; restore a pre-migration backup instead."
  end
end
