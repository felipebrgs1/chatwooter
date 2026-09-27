defmodule Chatwooter.Repo.Migrations.AlignOperationalCrmSchemaParity do
  use Ecto.Migration

  def up do
    execute """
    ALTER TABLE contact_inboxes DROP CONSTRAINT contact_inboxes_contact_id_fkey, DROP CONSTRAINT contact_inboxes_inbox_id_fkey
    """

    execute """
    ALTER TABLE contacts DROP CONSTRAINT contacts_account_id_fkey, DROP CONSTRAINT contacts_company_id_fkey
    """

    execute """
    ALTER TABLE companies DROP CONSTRAINT companies_account_id_fkey
    """

    execute """
    DROP INDEX contacts_account_id_index
    """

    execute """
    DROP INDEX contacts_account_id_phone_number_index
    """

    execute """
    DROP INDEX contacts_company_id_index
    """

    execute """
    DROP INDEX contact_inboxes_contact_id_inbox_id_index
    """

    execute """
    DROP INDEX contact_inboxes_inbox_id_source_id_index
    """

    execute """
    DROP INDEX companies_account_id_index
    """

    execute """
    DROP INDEX companies_account_id_name_index
    """

    execute """
    DROP INDEX companies_account_id_domain_index
    """

    execute """
    ALTER TABLE contacts RENAME COLUMN inserted_at TO created_at
    """

    execute """
    ALTER TABLE contact_inboxes RENAME COLUMN inserted_at TO created_at
    """

    execute """
    ALTER TABLE companies RENAME COLUMN inserted_at TO created_at
    """

    execute """
    ALTER TABLE contacts
     ALTER COLUMN id TYPE integer,
     ALTER COLUMN account_id TYPE integer,
     ALTER COLUMN name TYPE character varying,
     ALTER COLUMN name DROP NOT NULL,
     ALTER COLUMN name SET DEFAULT '',
     ALTER COLUMN email TYPE character varying,
     ALTER COLUMN phone_number TYPE character varying,
     ALTER COLUMN additional_attributes DROP NOT NULL,
     ALTER COLUMN created_at TYPE timestamp,
     ALTER COLUMN updated_at TYPE timestamp,
     ADD COLUMN identifier character varying,
     ADD COLUMN custom_attributes jsonb DEFAULT '{}',
     ADD COLUMN last_activity_at timestamp,
     ADD COLUMN contact_type integer DEFAULT 0,
     ADD COLUMN middle_name character varying DEFAULT '',
     ADD COLUMN last_name character varying DEFAULT '',
     ADD COLUMN location character varying DEFAULT '',
     ADD COLUMN country_code character varying DEFAULT '',
     ADD COLUMN blocked boolean DEFAULT false NOT NULL
    """

    execute """
    ALTER SEQUENCE contacts_id_seq AS integer
    """

    execute """
    ALTER TABLE contact_inboxes
     ALTER COLUMN contact_id DROP NOT NULL,
     ALTER COLUMN inbox_id DROP NOT NULL,
     ALTER COLUMN source_id TYPE text,
     ALTER COLUMN created_at TYPE timestamp(6),
     ALTER COLUMN updated_at TYPE timestamp(6),
     ADD COLUMN hmac_verified boolean DEFAULT false,
     ADD COLUMN pubsub_token character varying
    """

    execute """
    ALTER TABLE companies
     ALTER COLUMN name TYPE character varying,
     ALTER COLUMN domain TYPE character varying,
     ALTER COLUMN created_at TYPE timestamp(6),
     ALTER COLUMN updated_at TYPE timestamp(6),
     ADD COLUMN contacts_count integer,
     ADD COLUMN last_activity_at timestamp
    """

    execute """
    CREATE INDEX index_contacts_on_lower_email_account_id ON contacts (lower((email)::text), account_id)
    """

    execute """
    CREATE INDEX index_contacts_on_account_id_and_contact_type ON contacts (account_id, contact_type)
    """

    execute """
    CREATE INDEX index_contacts_on_nonempty_fields ON contacts (account_id, email, phone_number, identifier) WHERE (((email)::text <> ''::text) OR ((phone_number)::text <> ''::text) OR ((identifier)::text <> ''::text))
    """

    execute """
    CREATE INDEX index_contacts_on_account_id_and_last_activity_at ON contacts (account_id, last_activity_at DESC NULLS LAST)
    """

    execute """
    CREATE INDEX index_contacts_on_account_id ON contacts (account_id)
    """

    execute """
    CREATE INDEX index_resolved_contact_account_id ON contacts (account_id) WHERE (((email)::text <> ''::text) OR ((phone_number)::text <> ''::text) OR ((identifier)::text <> ''::text))
    """

    execute """
    CREATE INDEX index_contacts_on_blocked ON contacts (blocked)
    """

    execute """
    CREATE INDEX index_contacts_on_company_id ON contacts (company_id)
    """

    execute """
    CREATE UNIQUE INDEX uniq_email_per_account_contact ON contacts (email, account_id)
    """

    execute """
    CREATE UNIQUE INDEX uniq_identifier_per_account_contact ON contacts (identifier, account_id)
    """

    execute """
    CREATE INDEX index_contacts_on_name_email_phone_number_identifier ON contacts USING gin (name gin_trgm_ops, email gin_trgm_ops, phone_number gin_trgm_ops, identifier gin_trgm_ops)
    """

    execute """
    CREATE INDEX index_contacts_on_phone_number_and_account_id ON contacts (phone_number, account_id)
    """

    execute """
    CREATE INDEX index_contact_inboxes_on_contact_id ON contact_inboxes (contact_id)
    """

    execute """
    CREATE UNIQUE INDEX index_contact_inboxes_on_inbox_id_and_source_id ON contact_inboxes (inbox_id, source_id)
    """

    execute """
    CREATE INDEX index_contact_inboxes_on_inbox_id ON contact_inboxes (inbox_id)
    """

    execute """
    CREATE UNIQUE INDEX index_contact_inboxes_on_pubsub_token ON contact_inboxes (pubsub_token)
    """

    execute """
    CREATE INDEX index_contact_inboxes_on_source_id ON contact_inboxes (source_id)
    """

    execute """
    CREATE UNIQUE INDEX index_companies_on_account_and_domain ON companies (account_id, domain) WHERE (domain IS NOT NULL)
    """

    execute """
    CREATE INDEX index_companies_on_account_id ON companies (account_id)
    """

    execute """
    CREATE INDEX index_companies_on_name_and_account_id ON companies (name, account_id)
    """
  end

  def down do
    raise Ecto.MigrationError,
      message:
        "CRM schema parity cannot be reversed without losing restored metadata. Restore a backup to return to the previous schema."
  end
end
