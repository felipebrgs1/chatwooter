# Marco 0 — inventário do banco (2026-09-26)

Referência **somente leitura**: `chatwoot/db/schema.rb`, versão `2026_09_24_000000`, commit upstream `845206aa6fd053998cfb153884afc2f464904e40`. O SHA-256 do arquivo e o catálogo comparativo de **todas as 103 tabelas** estão em [`schema_parity_baseline.json`](schema_parity_baseline.json). O relatório foi produzido contra o PostgreSQL do Docker após as migrações atuais; para reproduzir em outro banco já migrado:

```sh
mix chatwooter.schema_diff --json docs/schema_parity_baseline.json
```

O comando só lê o banco. O relatório contém por tabela: PK, colunas (tipo, precisão, nulidade e default), índices (nome, chaves, unicidade, método, predicado, opclass e ordenação esperados), FKs e checks; também extensões e presença de triggers. `equal` = coincidência do contrato medido; `different`/`missing` = **pendente**, não transformação aprovada; `local_only` = adição nossa, não eliminada automaticamente. Transformações aceitas exigirão teste próprio e decisão registrada. Tabelas Phoenix/Oban extras são informadas, mas não bloqueiam a paridade das 103 tabelas upstream.

## Resultado inicial

- **10/103** tabelas presentes, **93 ausentes**; as 10 ainda não são estruturalmente equivalentes. `users_tokens` e `oban_jobs` (além de tabelas de controle do Ecto) são locais.
- Ausências de colunas em tabelas existentes: `account_users` 5, `accounts` 10, `attachments` 8, `companies` 3, `contact_inboxes` 3, `contacts` 10, `conversations` 22, `inboxes` 17, `messages` 7 e `users` 28. Ver **nomes e valores** no JSON, inclusive FKs e índices em desacordo.
- Bloqueios do corte WA/TG: `conversations.display_id` + sequência por conta e trigger; `inboxes.channel_id` e `channel_whatsapp`/`channel_telegram`; campos de histórico em `messages`; `teams`, `team_members`, `inbox_members`; contato e suas uniques. `status`/`message_type` aqui são strings onde o snapshot usa inteiros. `id` das tabelas Rails `:serial` é `integer`, mas aqui é `bigint`. Nenhum desses é aprovado como equivalente por acidente.
- Sem extensões exigidas pelo snapshot (ver diferenças de `pg_trgm`, `pgcrypto`, `vector`, `pg_stat_statements` no relatório). Avaliar instalação em ambiente alvo antes de criar índices GIN/vetoriais.

## Riscos que exigem contrato fora do schema.rb

- O snapshot **não declara valores dos enums** Rails, lógica dos modelos, validações aplicacionais, corpos de funções PL/pgSQL nem todos os efeitos de migrações. Trigger `body_unverified` indica que só a presença foi comparada; mesmo com diff vazio, validar manualmente os corpos e comportamento. Comparação de índices por nome/chaves/método/predicado não substitui inspeção manual de opclass/ordem/expressões equivalentes. Nenhuma alegação 1:1 só com este relatório.
- `created_at` (Rails) vs `inserted_at` (Ecto), tipos de PK, strings de enum e mídia ActiveStorage vs nosso storage exigem transformações com testes. **Não** reescrever migrações existentes sem estratégia de backfill.
- Dados sensíveis: contatos (email/telefone), `users` (hashes de senha e tokens), `access_tokens`, `channel_whatsapp` (credenciais), `channel_telegram` (token), `channel_email`, integrações e segredos de `provider_config`. Inventariar os campos no JSON sem exportar seus valores; criptografar Meta/Telegram ao importar e jamais copiar hashes Devise como login Phoenix.
- Funcionalidades fora do corte operacional (Captain, campanhas, portais, outros canais, Rails storage) permanecem exigidas pela meta **estrutural** das 103 tabelas; mantê-las desativadas. Não há equivalência operacional implícita.

**Próximo lote (marco 1):** testes de migração e backfill com banco vazio e populado para identidade/equipes, tabela `import_mappings`, detecção de colisões e ensaio de importação idempotente. Depois seguir marcos 2–6 do `ROADMAP_PARIDADE_BANCO.md`. Não aplicar constraints incompatíveis antes de reconciliar dados reais.
