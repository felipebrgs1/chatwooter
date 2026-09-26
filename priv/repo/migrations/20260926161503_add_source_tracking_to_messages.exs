defmodule Chatwooter.Repo.Migrations.AddSourceTrackingToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      # ID da mensagem no provider (wamid, telegram message_id...).
      # Nulo p/ mensagens criadas no dashboard; NULLs nao conflitam no unique.
      add :source_id, :string
      add :content_type, :string, null: false, default: "text"
    end

    # Idempotencia de ingest: retry do provider nao duplica mensagem.
    create unique_index(:messages, [:conversation_id, :source_id])
  end
end
