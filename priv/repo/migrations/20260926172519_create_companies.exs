defmodule Chatwooter.Repo.Migrations.CreateCompanies do
  use Ecto.Migration

  def change do
    create table(:companies) do
      add :name, :string, null: false
      add :domain, :string
      add :description, :text
      add :additional_attributes, :map, default: %{}
      add :account_id, references(:accounts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:companies, [:account_id])
    create index(:companies, [:account_id, :name])
    create unique_index(:companies, [:account_id, :domain], where: "domain IS NOT NULL")

    alter table(:contacts) do
      add :company_id, references(:companies, on_delete: :nilify_all)
    end

    create index(:contacts, [:company_id])
  end
end
