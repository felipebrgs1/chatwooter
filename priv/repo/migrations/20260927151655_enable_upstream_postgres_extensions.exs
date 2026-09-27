defmodule Chatwooter.Repo.Migrations.EnableUpstreamPostgresExtensions do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")
    execute("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")
  end

  def down do
    # Extensions may be shared with other objects or schemas in the database.
    :ok
  end
end
