defmodule Chatwooter.Repo.Migrations.CompleteInboxSerialAndTimestampContract do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE inboxes ALTER COLUMN id SET DEFAULT nextval('inboxes_id_seq'::regclass)"
    execute "ALTER TABLE inboxes ALTER COLUMN created_at TYPE timestamp without time zone"
  end

  def down do
    raise Ecto.MigrationError,
      message:
        "Restore a pre-migration backup to reverse inbox parity without losing restored data."
  end
end
