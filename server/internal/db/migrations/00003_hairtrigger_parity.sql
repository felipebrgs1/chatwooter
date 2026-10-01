-- +goose Up
-- Triggers de display_id iguais aos do Chatwoot: o hairtrigger cria uma função com o nome do trigger e sempre
-- sobrescreve o display_id. Também tira o que o baseline herdou do app Elixir e do pg_dump: as tabelas
-- import_* (sem uso) e as sequências de display_id de contas que não existem.
-- Idempotente porque o baseline pode ter sido adotado de um dump do próprio Chatwoot (db.adoptExistingSchema).
-- +goose StatementBegin
DROP TRIGGER IF EXISTS accounts_after_insert_row_tr ON accounts;
DROP TRIGGER IF EXISTS camp_dpid_before_insert ON accounts;
DROP TRIGGER IF EXISTS conversations_before_insert_row_tr ON conversations;
DROP TRIGGER IF EXISTS campaigns_before_insert_row_tr ON campaigns;
DROP FUNCTION IF EXISTS chatwooter_create_conv_dpid_seq();
DROP FUNCTION IF EXISTS chatwooter_create_camp_dpid_seq();
DROP FUNCTION IF EXISTS chatwooter_assign_conv_dpid();
DROP FUNCTION IF EXISTS chatwooter_assign_camp_dpid();

CREATE OR REPLACE FUNCTION accounts_after_insert_row_tr()
RETURNS TRIGGER AS $$
BEGIN
    execute format('create sequence IF NOT EXISTS conv_dpid_seq_%s', NEW.id);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER accounts_after_insert_row_tr AFTER INSERT ON accounts
FOR EACH ROW EXECUTE PROCEDURE accounts_after_insert_row_tr();

CREATE OR REPLACE FUNCTION conversations_before_insert_row_tr()
RETURNS TRIGGER AS $$
BEGIN
    NEW.display_id := nextval('conv_dpid_seq_' || NEW.account_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER conversations_before_insert_row_tr BEFORE INSERT ON conversations
FOR EACH ROW EXECUTE PROCEDURE conversations_before_insert_row_tr();

CREATE OR REPLACE FUNCTION camp_dpid_before_insert()
RETURNS TRIGGER AS $$
BEGIN
    execute format('create sequence IF NOT EXISTS camp_dpid_seq_%s', NEW.id);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER camp_dpid_before_insert AFTER INSERT ON accounts
FOR EACH ROW EXECUTE PROCEDURE camp_dpid_before_insert();

CREATE OR REPLACE FUNCTION campaigns_before_insert_row_tr()
RETURNS TRIGGER AS $$
BEGIN
    NEW.display_id := nextval('camp_dpid_seq_' || NEW.account_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER campaigns_before_insert_row_tr BEFORE INSERT ON campaigns
FOR EACH ROW EXECUTE PROCEDURE campaigns_before_insert_row_tr();

DROP TABLE IF EXISTS import_errors, import_mappings, import_runs;

DO $$
DECLARE seq record;
BEGIN
    FOR seq IN
        SELECT c.relname FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
        WHERE ns.nspname = current_schema() AND c.relkind = 'S' AND c.relname ~ '^(conv|camp)_dpid_seq_\d+$'
          AND NOT EXISTS (SELECT 1 FROM accounts a WHERE a.id = substring(c.relname FROM '\d+$')::bigint)
    LOOP
        EXECUTE format('DROP SEQUENCE %I', seq.relname);
    END LOOP;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- Sem volta: o estado anterior era divergência do Chatwoot, e as tabelas import_* não tinham uso.
SELECT 1;
