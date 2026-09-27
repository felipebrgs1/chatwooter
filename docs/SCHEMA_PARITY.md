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

## Avanço do marco 1 — equipes e membros

A migração incremental `20260927010425_create_teams_and_memberships.exs` adiciona `teams`, `team_members` e `inbox_members` com índices e defaults do snapshot. `20260927010614_align_membership_timestamp_precision.exs` corrige a precisão SQL sem reescrever a migração já aplicada. O teste `test/chatwooter/accounts_teams_test.exs` cobre contas já populadas, duplicatas, isolamento por conta e os metadados do PostgreSQL. **13/103** tabelas agora existem; isto não significa paridade 13/103.

O JSON `schema_parity_baseline.json` é o inventário **inicial**, não o estado atual. Para medir o banco depois destas migrações, execute novamente `mix chatwooter.schema_diff` (ou use `--json` com outro caminho). Permanecem diferenças explícitas: `inbox_members.user_id`/`inbox_id` são `bigint` para referenciar as PKs locais (`users`/`inboxes`), contra `integer` no Rails; as FKs de equipes/membros são constraints locais adicionais que não constam do snapshot. Alterar tipos exige planejamento e backfill de IDs existentes. O catálogo não mascara esses desvios.

## Avanço do marco 1 — IDs e retomada de agentes

`import_mappings` é tabela **local** (não uma das 103 do snapshot, nem equivalente a `data_import_mappings` do Rails). A migração `20260927011015_create_import_mappings.exs` mantém o par original/destino por conta e tabela, com índices únicos nas duas direções e checks para IDs positivos e tabelas habilitadas. `Chatwooter.Imports.record_mapping/4` verifica a existência do destino **dentro da conta** antes de gravar; reexecução idêntica retorna o mesmo mapeamento, colisão retorna `:conflict`. A referência polimórfica `new_id` não tem FK SQL: gravações devem passar pelo serviço e a remoção posterior do destino é detectada ao retomar.

`Chatwooter.Imports.import_agent/2` importa **uma linha normalizada** (IDs, nome/email e enums inteiros Rails para papel/disponibilidade), transaciona agente, vínculo e mapeamento, reaproveita usuários por email sem sobrescrever credenciais/papéis existentes e detecta `:source_changed`/`:stale_mapping`. Apenas nome, email e enums são aceitos; hash Devise e tokens não são lidos. Ainda **não** há execução em Oban, importação de equipes/inboxes ou teste com export de produção. O teste `test/chatwooter/imports_test.exs` usa linhas simuladas e contas isoladas. A mesma conta de destino pressupõe **uma** conta de origem; consolidar múltiplas contas exigirá uma chave de origem adicional.

## Avanço do marco 1 — lotes e leitura da origem

A migração `20260927011646_create_import_runs_and_errors.exs` cria duas tabelas **locais**: `import_runs` fixa um único `source_account_id` por conta de destino; `import_errors` guarda apenas tabela, ID e código allowlisted. `Chatwooter.Imports.import_agents/3` recebe um Enumerable completo de agentes, grava progresso, retoma após falha parcial e apaga erros resolvidos; reexecução não duplica mapeamentos. Interrupção do stream deixa o lote `running`, pronto para uma nova tentativa. A execução **deve ser serializada por conta** pelo worker futuro: chamadas concorrentes ainda não têm lock distribuído. `processed_count` é o número de linhas na última tentativa completa, não a contagem vitalícia.

`Chatwooter.Imports.Source.read_agents/4` e `stream_agents/3` leem `users` + `account_users` da conta original com keyset pagination (até 500 linhas), projetando só nome, email, IDs, papel e disponibilidade. Cada página usa transação PostgreSQL `READ ONLY`; a conexão deve ser uma **Postgrex separada da Repo local**, criada com credenciais de origem de menor privilégio (`SELECT` somente). O modo de transação sozinho **não substitui** a role SQL read-only: PostgreSQL ainda permite alterações em tabelas temporárias. Não há URL ou segredo persistido nas tabelas de importação. `test/chatwooter/import_source_test.exs` ensaia a leitura em tabelas temporárias isoladas e retoma após corrigir uma linha inválida; **não** usa um export real do Chatwoot. Uma página por transação não produz snapshot consistente se a origem mudar durante a importação: exigir freeze/cópia consistente no corte.

## Avanço — prévia de mapeamentos e conexão isolada

`Chatwooter.Imports.preview_agents/3` percorre o mesmo stream e devolve **apenas contagens** de origem, mapeados, pendentes e mapeamentos sem membro de conta. Não cria `import_runs`, usuários nem mappings; rejeita origem diferente se a conta já estiver vinculada a uma importação. A prévia **não valida campos** (email, enums, mídia) nem garante que um ID mapeado corresponda ao conteúdo atual da origem; portanto não é ensaio de importação completo nem reconciliação de produção. `Source.with_connection/2` recebe opções Postgrex confiáveis (não argumentos do job), força `default_transaction_read_only=on` na sessão, devolve resultado sem revelar credenciais e fecha a conexão mesmo se a leitura falhar. Isso é defesa adicional, não prova de privilégios: **usar role PostgreSQL só com SELECT e TLS no ambiente de produção**.

**Próximo lote:** disponibilizar credenciais da origem via segredo de runtime, worker Oban serializado por conta, dry-run/reconciliação de contagens por tabela e ensaio em cópia anonimizadas. A importação integral de uma conta WA/TG ainda não foi implementada.

## Riscos que exigem contrato fora do schema.rb

- O snapshot **não declara valores dos enums** Rails, lógica dos modelos, validações aplicacionais, corpos de funções PL/pgSQL nem todos os efeitos de migrações. Trigger `body_unverified` indica que só a presença foi comparada; mesmo com diff vazio, validar manualmente os corpos e comportamento. Comparação de índices por nome/chaves/método/predicado não substitui inspeção manual de opclass/ordem/expressões equivalentes. Nenhuma alegação 1:1 só com este relatório.
- `created_at` (Rails) vs `inserted_at` (Ecto), tipos de PK, strings de enum e mídia ActiveStorage vs nosso storage exigem transformações com testes. **Não** reescrever migrações existentes sem estratégia de backfill.
- Dados sensíveis: contatos (email/telefone), `users` (hashes de senha e tokens), `access_tokens`, `channel_whatsapp` (credenciais), `channel_telegram` (token), `channel_email`, integrações e segredos de `provider_config`. Inventariar os campos no JSON sem exportar seus valores; criptografar Meta/Telegram ao importar e jamais copiar hashes Devise como login Phoenix.
- Funcionalidades fora do corte operacional (Captain, campanhas, portais, outros canais, Rails storage) permanecem exigidas pela meta **estrutural** das 103 tabelas; mantê-las desativadas. Não há equivalência operacional implícita.

Depois seguir marcos 2–6 do `ROADMAP_PARIDADE_BANCO.md`. Não aplicar constraints incompatíveis antes de reconciliar dados reais. Ainda faltam ensaios completos de migração em banco já populado, rollback e importação real; os testes deste lote usam dados pré-existentes nas tabelas de conta/inbox, mas não simulam um upgrade de uma cópia de produção.
