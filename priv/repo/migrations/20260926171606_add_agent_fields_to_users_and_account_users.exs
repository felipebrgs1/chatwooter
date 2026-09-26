defmodule Chatwooter.Repo.Migrations.AddAgentFieldsToUsersAndAccountUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :name, :string
    end

    alter table(:account_users) do
      add :availability, :string, default: "online", null: false
      add :auto_offline, :boolean, default: false, null: false
    end

    create index(:account_users, [:account_id, :availability])

    execute(
      "UPDATE users SET name = split_part(email, '@', 1) WHERE name IS NULL",
      "SELECT 1"
    )
  end

  def down do
    alter table(:account_users) do
      remove :availability
      remove :auto_offline
    end

    alter table(:users) do
      remove :name
    end
  end
end
