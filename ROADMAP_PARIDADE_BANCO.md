# Roadmap — paridade do banco Chatwoot → Chatwooter

Referência congelada: `chatwoot/db/schema.rb` (versão `2026_09_24_000000`) e os modelos/migrações em `chatwoot/` (**somente leitura**). Estado medido e decisões: [`docs/SCHEMA_PARITY.md`](docs/SCHEMA_PARITY.md).

## O que significa “1:1”

- **Paridade estrutural:** as mesmas 103 tabelas do snapshot, com colunas, tipos, precisão, nulidade, defaults, índices, checks, FKs, extensões e triggers. Tabelas próprias Phoenix/Oban coexistem. ✅ **Concluída.**
- **Paridade de dados:** `pg_dump` → `pg_restore` preservando IDs, relações e sequências; os contexts Ecto leem os formatos Rails diretamente, sem remapeamento. Leitura provada com dados sintéticos; falta o ensaio com dump real.
- **Paridade operacional:** inboxes WhatsApp Cloud API e Telegram abrem, exibem e respondem às conversas restauradas. Não inclui reproduzir Rails/Devise/ActiveStorage nem ativar outros canais, campanhas ou Captain; esses dados ficam preservados e rastreáveis, sem aparecer como operacionais.

## Marcos

| Marco | Entrega | Estado |
|---|---|---|
| 0 — Contrato e inventário | Snapshot congelado, `make schema-diff` (Go, `server/internal/schemaparity`), gate `TestMigratedDatabaseMatchesUpstreamSnapshot` | ✅ |
| 1 — Identidade | contas, usuários, membership, equipes, `(uid, provider)`, Devise vazio → `nil` | ✅ estrutural |
| 2 — CRM e canais | contatos, empresas, inboxes, `channel_whatsapp`/`channel_telegram`, etiquetas, notas, atributos | ✅ estrutural |
| 3 — Conversas e mídia | `display_id` por conta com triggers, mensagens, anexos, participantes | ✅ estrutural |
| 4 — Plataforma | tokens, webhooks, notificações, CSAT, SLA, automações | ✅ estrutural |
| 5 — Cobertura integral | demais tabelas (canais fora do v1, ActiveStorage, help center, campanhas, Captain, monitores) como preservação | ✅ 103/103 |
| 6 — Prova de migração e corte | restauração de dump real, bootstrap local, autenticação, operação WA/TG | ⏳ pendente |

## Marco 6 — critérios de saída

1. Duas restaurações de um export real anonimizado em destinos limpos preservam IDs, sequências, contagens e relações.
2. Procedimento de bootstrap das tabelas locais (Phoenix/Oban/`chatwooter_*`) e reconciliação do ledger `schema_migrations` sobre o banco restaurado. Não rodar as migrações de criação sobre tabelas restauradas.
3. Usuários restaurados conseguem autenticar; segredos Meta/Telegram revisados e protegidos antes do uso, nunca em texto puro nem em logs.
4. Conversa real aberta e respondida nos dois canais em sandbox, sem instalar webhooks externos durante o dry-run; relatório explícito dos canais não ativados.
5. Guia de freeze/cutover WA+TG.

## Regras para mudanças no schema

1. Teste primeiro; `TestMigratedDatabaseMatchesUpstreamSnapshot` (Go) deve continuar exigindo igualdade total com o snapshot.
2. Migrações novas via `mix ecto.gen.migration`; nunca reescrever migrações aplicadas.
3. Transformações Rails ↔ Ecto (enums, timestamps, JSON/JSONB, polimorfismo, ActiveStorage) são testadas com dados restaurados, nunca presumidas.
4. Antes de `NOT NULL`/unique em banco existente: detectar conflitos → backfill em lotes → constraint.
5. Direção dos contexts (`Channels → Conversations → Contacts → Inboxes → Accounts`), sem `ChatwooterWeb → Repo`.
6. `mix precommit` verde.
