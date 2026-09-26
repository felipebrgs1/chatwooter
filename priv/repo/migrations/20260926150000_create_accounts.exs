defmodule Chatwooter.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :name, :string, null: false
      add :locale, :string, null: false, default: "pt-BR"
      add :settings, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create table(:account_users) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "agent"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:account_users, [:account_id, :user_id])
    create index(:account_users, [:user_id])
  end
end
