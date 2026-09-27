# Paridade do banco — estado

## Referência

- Origem somente leitura: `chatwoot/db/schema.rb`, versão `2026_09_24_000000`, commit upstream `845206aa6fd053998cfb153884afc2f464904e40` (SHA-256 `128ffd15948a3d9dac6ab68185f7742de3ddc40f61a20474de038faa4f3246cc`).
- Medição atual: [`schema_parity_progress.json`](./schema_parity_progress.json). `schema_parity_baseline.json` é o relatório inicial congelado (10 tabelas) e o `schema_diff` se recusa a sobrescrevê-lo.

```sh
mix chatwooter.schema_diff
mix chatwooter.schema_diff --json /tmp/chatwooter-schema-diff.json
```

O diff compara o catálogo físico de um banco **migrado** ao snapshot: colunas (tipo, precisão, nulidade, default), PKs, índices (chaves, unicidade, método, predicado, opclasses, ordem), FKs, checks, extensões e presença de triggers. `schema_parity_test.exs` exige igualdade em tudo isso e tem provas negativas de default, índice, opclass, ordenação, predicado e check.

## Estado: paridade estrutural completa

Banco limpo (`ecto.create` → `ecto.migrate` → `schema_diff`):

| Item | Resultado |
|---|---|
| Tabelas | 103/103 presentes, 0 ausentes |
| Colunas / PKs | 1129 / 103 iguais, nenhuma faltando ou sobrando |
| Índices / FKs / checks | 334 / 17 / 1 iguais |
| Extensões | `pg_stat_statements`, `pg_trgm`, `pgcrypto`, `plpgsql`, `vector` — idênticas ao snapshot |
| Triggers | 4/4 presentes; corpo conferido manualmente (abaixo) |

`parity?` do relatório fica `false` só porque o catálogo não consegue verificar corpos de função (`body_unverified`).

Tabelas locais que coexistem com as upstream: `users_tokens`, `oban_jobs`, `oban_peers`, `schema_migrations`, `chatwooter_inbox_configs`, `chatwooter_attachment_storage` e os helpers históricos `import_runs`, `import_errors`, `import_mappings`.

### Triggers de `display_id`

Conferência de `chatwoot/db/schema.rb` (hairtrigger) contra `pg_get_triggerdef`/`pg_proc.prosrc`:

| Trigger | Tabela / momento | Corpo upstream | Local |
|---|---|---|---|
| `accounts_after_insert_row_tr` | `accounts` AFTER INSERT, por linha | `CREATE SEQUENCE IF NOT EXISTS conv_dpid_seq_<id>` | igual, função `chatwooter_create_conv_dpid_seq()` |
| `camp_dpid_before_insert` | `accounts` AFTER INSERT, por linha | `CREATE SEQUENCE IF NOT EXISTS camp_dpid_seq_<id>` | igual, função `chatwooter_create_camp_dpid_seq()` |
| `conversations_before_insert_row_tr` | `conversations` BEFORE INSERT, por linha | sempre `nextval('conv_dpid_seq_' \|\| account_id)` | só quando `display_id IS NULL`, função `chatwooter_assign_conv_dpid()` |
| `campaigns_before_insert_row_tr` | `campaigns` BEFORE INSERT, por linha | sempre `nextval('camp_dpid_seq_' \|\| account_id)` | só quando `display_id IS NULL`, função `chatwooter_assign_camp_dpid()` |

Desvios deliberados: (1) funções com nomes próprios (o hairtrigger usa o nome da trigger); nada as chama diretamente; (2) as BEFORE preservam `display_id` explícito para não renumerar linhas restauradas. Em inserts normais o comportamento é o do Rails. A migração `20260927040317` é irreversível de propósito: as sequências definem a numeração das conversas.

## Decisões de leitura dos dados Rails

Permanentes e cobertas por testes de dados restaurados (`*_restored_data_test.exs`):

- **Identidade:** `users.encrypted_password` vazio do Devise lê como `nil` (`Types.PasswordHash`); email é nullable/não-unique e a identidade é `(uid, provider)`; login nunca autentica um match arbitrário entre duplicatas restauradas. Rótulo de papel `administrator`, igual ao Rails.
- **Inboxes:** config local fica em `chatwooter_inbox_configs`, fora da tabela upstream; `channel_type` preserva `Channel::Telegram/Whatsapp/...` (`Types.InboxChannel`) e `channel_id` aponta para `channel_telegram`/`channel_whatsapp`.
- **Mensagens e anexos:** `messages.content_type` inteiro é lido como `upstream_content_type`; o tipo de mídia do dashboard vive em `content_attributes.chatwooter_media_type`. Metadados de storage local ficam em `chatwooter_attachment_storage`; anexo restaurado sem storage local usa `external_url`.
- **Enums Rails** são lidos como inteiros (ou `Ecto.Enum` sobre os mesmos valores); nenhum valor é convertido.
- **FKs:** tabelas sem FK SQL no upstream continuam sem FK; exclusões em cascata são coordenadas por `Platform.RecordDeletion`.
- **Segredos:** tokens, certificados e configs são redigidos na inspeção dos structs. Isso não criptografa dump nem banco.

## Tabelas só de preservação

Existem com o formato original e mappings Ecto de leitura, sem recurso ativo: canais fora do v1 (API, email, Facebook, Instagram, LINE, SMS, Twilio, TikTok, Twitter, widget), help center, campanhas, Captain/Copilot/embeddings, monitores de conversa, SLA, automações/macros/bots, SAML, capacidade/atribuição, relatórios, auditoria, `data_import*` e ActiveStorage (só metadados; binários não migram).

## Pendente para migrar um Chatwoot real

Fluxo escolhido: `pg_dump` → `pg_restore`, preservando IDs, relações e sequências, sem remapeamento. Não rodar as migrações de criação sobre um schema restaurado (as tabelas já existem e o ledger Ecto não corresponde ao Rails).

1. Ensaio com dump integral real anonimizado em banco isolado: reconciliar contagens, relações e sequências. Até agora só houve dumps sintéticos.
2. Bootstrap das tabelas locais (Phoenix/Oban/`chatwooter_*`) e reconciliação do ledger `schema_migrations` sobre o banco restaurado.
3. Autenticação de usuários restaurados (Devise → Phoenix) e proteção dos segredos Meta/Telegram antes do uso.
4. Operação sandbox WA/TG sobre conversas restauradas.
