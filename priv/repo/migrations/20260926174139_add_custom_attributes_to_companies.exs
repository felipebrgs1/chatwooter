defmodule Chatwooter.Repo.Migrations.AddCustomAttributesToCompanies do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :custom_attributes, :map, default: %{}
    end
  end
end
