defmodule Chatwooter.Repo.Migrations.DropUnusedCitextExtension do
  use Ecto.Migration

  # users.email virou varchar no alinhamento de identidade; citext ficou órfã e
  # é a única extensão fora do snapshot do Chatwoot.
  def up do
    execute("DROP EXTENSION IF EXISTS citext")
  end

  def down do
    execute("CREATE EXTENSION IF NOT EXISTS citext")
  end
end
