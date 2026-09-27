defmodule Chatwooter.Repo.Migrations.AlignMembershipTimestampPrecision do
  use Ecto.Migration

  def up do
    for table <- ~w(teams team_members) do
      execute "ALTER TABLE #{table} ALTER COLUMN created_at TYPE timestamp(6) without time zone, ALTER COLUMN updated_at TYPE timestamp(6) without time zone"
    end

    execute "ALTER TABLE inbox_members ALTER COLUMN created_at TYPE timestamp without time zone, ALTER COLUMN updated_at TYPE timestamp without time zone"
  end

  def down do
    for table <- ~w(teams team_members) do
      execute "ALTER TABLE #{table} ALTER COLUMN created_at TYPE timestamp without time zone, ALTER COLUMN updated_at TYPE timestamp without time zone"
    end

    execute "ALTER TABLE inbox_members ALTER COLUMN created_at TYPE timestamp(0) without time zone, ALTER COLUMN updated_at TYPE timestamp(0) without time zone"
  end
end
