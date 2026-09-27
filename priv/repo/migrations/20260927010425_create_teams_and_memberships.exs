defmodule Chatwooter.Repo.Migrations.CreateTeamsAndMemberships do
  use Ecto.Migration

  def change do
    create table(:teams) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :allow_auto_assign, :boolean, default: true
      add :icon, :string, default: ""
      add :icon_color, :string, default: ""

      timestamps(type: :naive_datetime_usec, inserted_at: :created_at)
    end

    create index(:teams, [:account_id], name: :index_teams_on_account_id)
    create unique_index(:teams, [:name, :account_id], name: :index_teams_on_name_and_account_id)

    create table(:team_members) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :naive_datetime_usec, inserted_at: :created_at)
    end

    create unique_index(:team_members, [:team_id, :user_id],
             name: :index_team_members_on_team_id_and_user_id
           )

    create index(:team_members, [:team_id], name: :index_team_members_on_team_id)
    create index(:team_members, [:user_id], name: :index_team_members_on_user_id)

    create table(:inbox_members, primary_key: [name: :id, type: :serial]) do
      add :inbox_id, references(:inboxes, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :naive_datetime, inserted_at: :created_at)
    end

    create unique_index(:inbox_members, [:inbox_id, :user_id],
             name: :index_inbox_members_on_inbox_id_and_user_id
           )

    create index(:inbox_members, [:inbox_id], name: :index_inbox_members_on_inbox_id)
  end
end
