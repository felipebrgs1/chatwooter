defmodule Chatwooter.Repo.Migrations.AddStatusToMessages do
  use Ecto.Migration

  # Estado de entrega de mensagens de saida (nulo p/ recebidas; receipts na Fase 3).
  def change do
    alter table(:messages) do
      add :status, :string
    end
  end
end
