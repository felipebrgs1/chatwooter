# Paridade do banco — estado e pendências

## Referência e medição

- Origem **somente leitura**: `chatwoot/db/schema.rb`, versão `2026_09_24_000000`, commit upstream `845206aa6fd053998cfb153884afc2f464904e40` (SHA-256 `128ffd15948a3d9dac6ab68185f7742de3ddc40f61a20474de038faa4f3246cc`).
- [`schema_parity_baseline.json`](schema_parity_baseline.json) é o **relatório inicial congelado**: 10 das 103 tabelas presentes na época. Não é o relatório atual e não deve ser sobrescrito.
- Banco migrado após o marco 1: **13/103 tabelas presentes, 90 ausentes**. As 13 não são equivalentes estruturalmente; `parity?` continua `false`. `users_tokens`, `oban_jobs`, `import_mappings`, `import_runs` e `import_errors` são tabelas locais extras.

Para medir **seu** PostgreSQL migrado sem alterar o baseline:

```sh
mix chatwooter.schema_diff
mix chatwooter.schema_diff --json /tmp/chatwooter-schema-diff.json
```

O comando compara catálogo físico (colunas/tipos/precisão/null/default, PKs, índices, FKs, checks, extensões e presença de triggers) ao snapshot. `equal` é igualdade do contrato medido; `different`/`missing` são pendências; `local_only` registra adições locais. Nem enum Rails, nem corpos de triggers, nem dados importados são provados por um diff vazio. Para a definição completa de 1:1 e a ordem dos marcos, ver [`ROADMAP_PARIDADE_BANCO.md`](../ROADMAP_PARIDADE_BANCO.md).

## Entregue até aqui

| Parte | Implementação | Prova / limite |
|---|---|---|
| Inventário | `SchemaParity`, `Snapshot` e `mix chatwooter.schema_diff`; baseline versionado de 103 tabelas | `test/chatwooter/schema_parity_test.exs`; baseline é histórico, não contador de progresso |
| Equipes e vínculos | `teams`, `team_members`, `inbox_members` + migração incremental de precisão de timestamps | `accounts_teams_test.exs`; `inbox_members.user_id/inbox_id` continuam `bigint` locais, contra `integer` Rails; FKs extras são reportadas |
| Correspondências | `import_mappings` por conta/tabela/ID original e novo; únicas nas duas direções | `imports_test.exs`; destino polimórfico sem FK SQL, verificado pelo serviço; só accounts/users/teams/inboxes habilitados |
| Agentes | importação de **linha normalizada** com enum Rails convertido; transação, reexecução idempotente e reaproveitamento de usuário por email | `imports_test.exs`; não copia hashes Devise, não migra outros objetos |
| Retomada | `import_runs` vincula uma origem por destino; `import_errors` guarda apenas ID e código allowlisted | `import_runs_test.exs`; `processed_count` mede a última tentativa completa, `running` permite retomar após interrupção; **sem exclusão entre workers concorrentes** |
| Leitura/ prévia | `Source` lê agentes via conexão Postgrex separada, keyset de até 500 linhas e transações `READ ONLY`; `preview_agents/3` conta mapeados/pendentes/stale sem escrita | `import_source_test.exs`; prévia não valida campos e não equivale a dry-run/reconciliação completa |

## Ainda bloqueia a migração

1. **Identidade e operação WA/TG:** `conversations.display_id` + sequência/trigger por conta; enums inteiros vs strings de status/mensagem; `inboxes.channel_id`, `channel_whatsapp` e `channel_telegram`; conteúdo e autor de mensagens, anexos/ActiveStorage, contatos e uniques. O índice único local `contacts(account_id, phone_number)` não corresponde ao índice não único do snapshot: detectar colisões antes de alterá-lo.
2. **Segurança/corte:** provisionar role PostgreSQL de origem apenas com `SELECT` e TLS; a transação `READ ONLY` sozinha não elimina privilégio de escrita nem garante snapshot consistente entre páginas. Nunca persistir segredos Meta/Telegram em texto puro nem usar hashes Devise para login Phoenix. A conexão da origem ainda não é configurada por segredo de runtime; não há worker Oban ou importação integral de conta.
3. **Prova:** testes com banco previamente populado e export anonimizado, rollback, reconciliação de contagens/relações, operação sandbox WA/TG e relatório dos canais não suportados. As outras 90 tabelas e os desvios das 13 presentes continuam pendentes para 1:1 literal.

**Próximo lote:** segredo de runtime para conexão com role `SELECT`, worker Oban serializado por conta e ensaio de importação de agentes em cópia anonimizadas. Nenhuma UI ou rota nova é pré-requisito para esse lote.
