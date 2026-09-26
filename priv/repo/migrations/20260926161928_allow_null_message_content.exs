defmodule Chatwooter.Repo.Migrations.AllowNullMessageContent do
  use Ecto.Migration

  # Midia sem legenda (caption nula no provider) nao tem texto.
  def change do
    alter table(:messages) do
      modify :content, :text, null: true, from: {:text, null: false}
    end
  end
end
