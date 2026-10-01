# Paridade do banco — ✅ concluída

O schema do Chatwooter é o do Chatwoot 4.18: `chatwoot/db/schema.rb`, versão `2026_09_24_000000`
(SHA-256 `128ffd15948a3d9dac6ab68185f7742de3ddc40f61a20474de038faa4f3246cc`). A cópia congelada usada nos testes
fica em `server/internal/schemaparity/testdata/schema.rb`.

## Como é garantida

O gate `TestMigratedDatabaseMatchesUpstreamSnapshot` (`server/internal/schemaparity`, roda no `make precommit`)
migra um banco limpo e compara o catálogo físico ao `schema.rb`. Ele exige igualdade em:

- as 103 tabelas: colunas (tipo, precisão, nulidade, default), PKs, índices (chaves, unicidade, método, predicado,
  opclasses, ordem), FKs com `on_delete` e checks. Coluna ou índice a mais numa tabela do Chatwoot também reprova;
- extensões (`pg_stat_statements`, `pg_trgm`, `pgcrypto`, `plpgsql`, `vector`);
- os 4 triggers de `display_id`: tabela, momento, evento, nome da função e corpo, conferidos contra o SQL que o
  hairtrigger gera (função com o nome do trigger; o BEFORE sempre sobrescreve o `display_id`);
- tabelas locais numa lista fechada: `chatwooter_attachment_storage`, `chatwooter_inbox_configs`,
  `chatwooter_sessions`, `goose_db_version` e as do River;
- nenhuma sequência solta (as `conv_dpid_seq_N`/`camp_dpid_seq_N` nascem com cada conta).

`compare_test.go` tem as provas negativas. Para medir outro banco: `make schema-diff`
(`go run ./cmd/schemadiff -json <arquivo>` grava o relatório completo).

Fora do gate (não aparece no `schema.rb`): `on_update` e nomes das FKs, ordem das colunas e os enums do Rails.
Os enums são lidos como inteiros e os nomes vivem nos models Go, com os mesmos valores dos models Rails.

## Decisões de leitura dos dados Rails

- **Identidade:** `users.encrypted_password` vazio do Devise nunca autentica; email é nullable/não-unique e a
  identidade é `(uid, provider)`; login nunca autentica um match arbitrário entre duplicatas restauradas.
- **Inboxes:** config local fica em `chatwooter_inbox_configs` (cifrada, AES-GCM, nunca sai na API); `channel_type`
  preserva `Channel::Telegram/Whatsapp/...`. Colunas upstream restauradas (ex.: `channel_telegram.bot_token`)
  continuam em claro, como no dump.
- **Anexos:** metadados de storage local ficam em `chatwooter_attachment_storage`; anexo restaurado sem storage
  local usa `external_url`.
- **FKs:** tabelas sem FK SQL no upstream continuam sem FK; exclusões em cascata são feitas pelos models (como o
  `dependent: :destroy` do Rails).
- **Tabelas só de preservação:** canais fora do v1, help center, campanhas, Captain, monitores, SLA, automações,
  SAML, relatórios, auditoria, `data_import*` e ActiveStorage existem com o formato original, sem recurso ativo.

## Regras para mudanças no schema

1. O gate continua exigindo igualdade total; schema novo do Chatwoot = atualizar `testdata/schema.rb` + migration.
2. Migration `goose` nova em `server/internal/db/migrations`; nunca reescrever o baseline nem migration aplicada.
3. Tabela própria só com prefixo `chatwooter_` e entrando na lista fechada do gate.
4. Antes de `NOT NULL`/unique em banco existente: detectar conflitos → backfill em lotes → constraint.

## Migrar um Chatwoot real (não feito)

Fluxo previsto: `pg_dump` → `pg_restore` completo (os triggers são criados depois dos dados, então os
`display_id` restaurados não mudam) e `make migrate`, que adota o schema existente sem recriá-lo
(`db.adoptExistingSchema`). Ainda não houve ensaio com dump real, nem com a operação WhatsApp/Telegram
sobre conversas restauradas.
