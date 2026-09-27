# Paridade do banco — estado e pendências

## Referência e medição

- Origem somente leitura: `chatwoot/db/schema.rb`, versão `2026_09_24_000000`, commit upstream `845206aa6fd053998cfb153884afc2f464904e40` (SHA-256 `128ffd15948a3d9dac6ab68185f7742de3ddc40f61a20474de038faa4f3246cc`).
- `schema_parity_baseline.json` permanece como relatório histórico inicial de 10 tabelas. O parser antigo interpretava strings Rails sem limite como varchar(255); o comparador agora usa varchar sem limite, conforme o [adapter PostgreSQL Rails 7.2.3.1](https://github.com/rails/rails/blob/v7.2.3.1/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb). O baseline não foi sobrescrito.
- Banco **limpo** migrado a partir deste checkout: **103/103 tabelas presentes e equivalentes no catálogo físico**. `parity?` continua `false`: os corpos das quatro triggers são marcados `body_unverified` e `citext` é uma extensão local extra. Tabelas Phoenix/Oban, `chatwooter_inbox_configs`, `chatwooter_attachment_storage` e helpers históricos de importação também são extras locais. Bancos de desenvolvimento/teste antigos podem conservar migrations revertidas; nunca inferir reprodutibilidade apenas de um banco existente.

```sh
mix chatwooter.schema_diff
mix chatwooter.schema_diff --json /tmp/chatwooter-schema-diff.json
```

O diff compara o catálogo físico: colunas/tipos/precisão/null/default, PKs, índices, FKs, checks, extensões e presença de triggers. Enums Rails, corpos de triggers, dados e semântica operacional exigem provas separadas.

## Fluxo escolhido: pg_dump → pg_restore

A migração real preservará IDs e relações via dump/restauração, sem remapeamento nem conexão online com o banco de origem. O worker de agentes e as variáveis `IMPORT_SOURCE_*` foram retirados. Os helpers antigos `Imports`/`Source` permanecem históricos, sem fazer parte do fluxo escolhido.

Não execute as migrações de criação diretamente sobre um schema Chatwoot restaurado: as tabelas já existem e o ledger Ecto não corresponde ao ledger Rails. Ainda é necessário definir o bootstrap de tabelas locais Phoenix/Oban, a reconciliação do ledger e a compatibilização da autenticação. Este lote não resolve esses pontos.

## Lote CRM entregue

| Tabela | Contrato e leitura |
|---|---|
| `labels` | bigint, varchar sem limite, cor default, nulidade e unique título/conta; consulta por conta |
| `notes` | conteúdo obrigatório, IDs preservados e usuário nullable; consulta por conta/contato |
| `canned_responses` | PK serial, account_id integer e timestamps sem precisão declarada; leitura preserva microssegundos |
| `custom_attribute_definitions` | enums Rails inteiros convertidos em Ecto.Enum, JSONB inclusive arrays/default `[]`, unique por chave/modelo/conta |
| `working_hours` | dia Rails 0–6 preservado sem conversão, campos nullable e boolean defaults; consulta por conta/inbox |

A migração reproduz a ausência de FKs SQL dessas cinco tabelas no snapshot. Não acrescenta constraints que rejeitariam dados aceitos pela origem. Schemas e consultas são de leitura; edição, validações Rails, horários operacionais e UI permanecem pendentes.

Provas realizadas:

- `crm_schema_parity_test.exs`: igualdade física das cinco tabelas, incluindo colunas, precisão, defaults, PKs, índices e ausência de FKs/checks adicionais.
- `crm_restored_data_test.exs`: IDs explícitos, título de 300 caracteres, JSONB, enums, timestamps e isolamento entre contas; unique por conta e títulos nulos.
- Banco temporário limpo migrado; cinco registros sintéticos exportados com `pg_dump -Fc` e restaurados com `pg_restore --exit-on-error` em outro banco vazio. As cinco consultas Ecto preservaram IDs, enum, array e microssegundos. Só Repo foi iniciado porque esse dump parcial não contém Oban. Isso não é prova de inicialização da aplicação com um dump integral.
- Rollback e reaplicação do lote aprovados em banco temporário separado; os dados anteriores fora das cinco tabelas não foram removidos pela migração.

## Lote de 20 tabelas de plataforma/conversas

| Grupo | Tabelas com igualdade no catálogo físico |
|---|---|
| Plataforma | `access_tokens`, `webhooks`, `dashboard_apps`, `integrations_hooks` |
| Notificações | `notifications`, `notification_settings`, `notification_subscriptions`, `mentions` |
| CRM/contas | `tags`, `taggings`, `custom_filters`, `custom_roles` |
| Conversas/qualidade | `conversation_participants`, `csat_survey_responses`, `reporting_events` |
| SLA | `sla_policies`, `applied_slas`, `sla_events` |
| Automações | `automation_rules`, `macros` |

Migração incremental `20260927015901_create_platform_and_conversation_parity_tables.exs`, aplicada em desenvolvimento e teste. Reproduz tipos, nulidade, defaults, precisão, PKs e todos os índices do snapshot; nenhuma dessas 20 tabelas possui FK SQL upstream. `pg_trgm` é ativada para o índice GIN de `tags`; rollback mantém a extensão porque outros objetos podem depender dela.

As 20 tabelas têm mappings Ecto de leitura nos contexts correspondentes. Enums continuam inteiros para preservar valores Rails sem atribuir comportamento a recursos ainda não implementados. JSONB aceita objetos, arrays e escalares; permissões usam `text[]`. Tokens, segredos e atributos de subscriptions são redigidos na inspeção padrão dos structs. Isso não criptografa o dump ou o banco nem protege logs de SQL; dados reais exigem a política de proteção do ambiente.

O comparador agora lê o default completo de `webhooks.subscriptions`, compara JSON pela estrutura, normaliza as representações equivalentes de array SQL vazio e consulta as opclasses reais dos índices. Um teste negativo altera default/opclass no contrato e confirma que o diff rejeita ambos.

Validação:

- `platform_schema_parity_test.exs`: as 20 tabelas passam no catálogo físico; prova independente de GIN/`gin_trgm_ops`.
- `platform_restored_data_test.exs` + `PlatformParityFixture`: uma linha por tabela, incluindo todos os tipos relevantes, IDs explícitos, campos polimórficos, arrays/objetos JSONB, permissões, flags, microssegundos, nulidade/defaults, unique CSAT e inspeção sem tokens.
- Banco temporário limpo migrado e populado; dump custom completo desse **banco sintético** com `pg_dump -Fc`, restauração em outro banco vazio com `pg_restore --single-transaction`; leitura das 20 linhas pelo Ecto, comparação de todos os campos da fixture/defaults, contagem de uma linha por tabela e próximo ID de cada sequência aprovados.
- Rollback removeu exatamente as 20 tabelas e preservou a conta de controle externa ao lote; reaplicação em banco populado aprovada.

Essas provas não equivalem a dump integral real de Chatwoot nem à implementação dos recursos, autorização, consultas de produto ou engines de automação/SLA. Não foram criadas rotas/UI, providers ou efeitos colaterais.

## Segundo lote de 20 tabelas (trabalho com subagentes)

| Grupo | Tabelas com igualdade no catálogo físico |
|---|---|
| Contas/capacidade (7) | `account_saml_settings`, `agent_capacity_policies`, `assignment_policies`, `inbox_assignment_policies`, `inbox_capacity_limits`, `leaves`, `folders` |
| Rails/storage/auditoria (5) | `active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records`, `action_mailbox_inbound_emails`, `audits` |
| Proveniência/plataforma (6) | `data_imports`, `data_import_items`, `data_import_mappings`, `data_import_errors`, `platform_apps`, `platform_app_permissibles` |
| Canais v1 (2) | `channel_whatsapp`, `channel_telegram` |

Quatro migrações incrementais, geradas via `mix ecto.gen.migration`, versões `20260927020930`, `20260927020931`, `20260927020933`, `20260927020934`, aplicadas em desenvolvimento e teste. Três subagentes implementaram os grupos de 7/5/6; o agente principal implementou WA/TG e coordenou RED/GREEN, integração e verificação conjunta.

Todos os campos e índices dessas 20 tabelas correspondem ao snapshot. As duas FKs ActiveStorage→blobs mantêm `NO ACTION`; nenhuma FK ausente na origem foi acrescentada. São preservados JSON versus JSONB, varchar limitado/ilimitado, IDs/valores bigint, datas, timestamps de precisão 6 ou sem precisão declarada, nulidade, defaults e inteiros de enum. Os 20 mappings Ecto são de leitura e preservação de dados.

Provas:

- `capacity_*`, `storage_*`, `data_platform_*`, `wa_tg_*`: comparação física por tabela e fixtures com IDs/defaults, formatos JSON, microssegundos, nulidade, uniques e FKs. RED executado antes da implementação pelo agente principal, sem aplicar migrações vazias.
- Banco temporário limpo migrado e populado com as quatro fixtures (20 linhas, uma por tabela), estados explícitos de sequência e uma conta de controle. `pg_dump -Fc` seguido de `pg_restore --single-transaction` em outro banco vazio passou. Ecto leu as 20 linhas com todos os campos/defaults da fixture iguais, contagens iguais a 1 e próximo ID de cada sequência preservado.
- Rollback das quatro migrações removeu todas e somente as 20 tabelas, mantendo a conta de controle; reaplicação em banco populado passou.
- Catálogo após o segundo lote: 58 tabelas upstream presentes, 45 iguais fisicamente, 13 ainda diferentes e 45 ausentes. Progresso medido em `schema_parity_progress.json`; baseline inicial permanece congelado.

Limites: ActiveStorage conserva metadados/relações, mas não transfere arquivos binários. SAML, políticas de capacidade, email Rails e importações upstream não foram ativados. As tabelas de canais preservam o formato original; não são usadas pelos adapters atuais e não resolvem `inboxes.channel_id/channel_type`. Redação de certificados/tokens/config na inspeção não criptografa segredos restaurados: a proteção e compatibilização antes de uso operacional continuam pendentes. Não foram criadas UI/rotas, jobs de importação ou webhooks externos. Captain não foi incluído neste lote.

## Terceiro lote de 20 tabelas (trabalho com subagentes)

| Grupo | Tabelas com igualdade no catálogo físico |
|---|---|
| Help center (5) | `portals`, `portals_members`, `categories`, `articles`, `related_categories` |
| Canais preservados (6) | `channel_api`, `channel_email`, `channel_facebook_pages`, `channel_instagram`, `channel_line`, `channel_sms` |
| Automações/configuração (7) | `agent_bots`, `agent_bot_inboxes`, `automation_rule_pending_executions`, `email_templates`, `installation_configs`, `platform_banners`, `reporting_events_rollups` |
| Widget/sessões (2) | `channel_web_widgets`, `user_sessions` |

Quatro migrações incrementais, versões `20260927021639`, `20260927021641`, `20260927021642`, `20260927021644`, aplicadas em desenvolvimento e teste. Três subagentes entregaram grupos de 5/6/7; o agente principal implementou widget/sessões, ajustou o comparador e validou a integração.

`portals_members` mantém a ausência de PK e timestamps: a associação é lida pela combinação portal/usuário, sem ID inventado. `user_sessions.user_id` mantém a FK upstream `NO ACTION`. Como dependência do portal, `inboxes` recebeu `portal_id` nullable bigint, sua FK `NO ACTION` e o índice correspondente; a tabela inboxes ainda tem outros desvios e não é declarada equivalente.

O comparador agora interpreta o default Ruby-hash conhecido de `portals.config` como JSON, sem executar Ruby, e captura decimais integralmente. Defaults float equivalentes (0/0.0) são comparados numericamente. Parênteses externos balanceados acrescentados pelo PostgreSQL aos predicados são normalizados sem remover o agrupamento interno; um teste negativo troca AND por OR e confirma a divergência. Os três índices únicos parciais de templates (instalação, conta e inbox) são testados por escopo.

Provas:

- `help_center_*`, `preserved_channels_*`, `configuration_*`, `widget_session_*`: comparação física das 20 tabelas e leitura dos valores/defaults, PK ausente, FK de sessão, credenciais redigidas, JSON, datas, timestamps, índices parciais e unicidade.
- Banco temporário limpo migrado, quatro fixtures totalizando 20 linhas, 19 estados de sequência e uma associação sem PK. Dump custom completo desse banco **sintético** e restauração transacional em outro banco vazio passaram. Todos os campos/defaults das fixtures, contagens, IDs e próximos valores das 19 sequências foram conferidos via Ecto.
- Rollback das quatro migrações removeu as 20 tabelas e o vínculo `inboxes.portal_id`, preservando os registros de conta e inbox de controle. Reaplicação em banco já populado passou. O rollback perde o conteúdo da coluna de vínculo removida; não equivale a rollback de produção sem backup.
- Catálogo após o lote do núcleo operacional: **78 presentes, 78 iguais, 0 diferentes e 25 ausentes**. A lista completa das tabelas iguais está em `schema_parity_progress.json`.

Esses canais adicionais, help center, bots, envio de email e configurações globais permanecem como preservação de dados. Nenhum adapter/SSO/login Rails, job pendente, servidor de widget ou recurso novo foi ativado. Não foram criadas rotas/UI, webhooks externos ou migração de binários. Redação de credenciais não substitui proteção do dump/banco. Captain não foi incluído.

## Lote de alinhamento do núcleo operacional (13 tabelas)

Cinco migrações incrementais (`20260927022734`, `20260927022743`, `20260927022754`, `20260927022811`, `20260927023433`) alinharam identidade (`accounts`, `users`, `account_users`), inboxes/vínculos (`inboxes`, `inbox_members`, `teams`, `team_members`), CRM (`contacts`, `contact_inboxes`, `companies`) e conversas (`conversations`, `messages`, `attachments`) ao snapshot. O teste global (`schema_parity_test.exs`) agora exige igualdade física de **todas** as 78 tabelas presentes, com provas negativas de default/índice/opclass/direção de ordenação.

Decisões de preservação, todas cobertas por teste de leitura de dados restaurados:

- `users.encrypted_password` vazio do Devise lê como `nil` (`Types.PasswordHash`); email é nullable/não-unique e a identidade passa a ser `(uid, provider)`; login nunca autentica um match arbitrário quando há duplicatas restauradas.
- `inboxes.provider_config` saiu da tabela upstream para `chatwooter_inbox_configs`; `channel_type` preserva `Channel::Telegram/Whatsapp/Email/...` via `Types.InboxChannel` e `channel_id` aponta para `channel_telegram`/`channel_whatsapp` criados na migração a partir do config local.
- `messages.content_type` inteiro upstream é lido como `upstream_content_type`; o tipo de mídia do dashboard (`image/audio/video/file/location`) é preservado em `content_attributes.chatwooter_media_type`. Metadados locais de anexo vivem em `chatwooter_attachment_storage`; linha restaurada sem storage local lê `url` de `external_url`.
- Tabelas upstream sem FKs SQL continuam sem FKs; cascatas locais foram substituídas por exclusão coordenada em `Platform.RecordDeletion` (usada pelos LiveViews e coberta pelo teste de cascata).
- `conversations.display_id` sai da sequence por conta `conv_dpid_seq_<account_id>`, com as triggers `accounts_after_insert_row_tr`, `conversations_before_insert_row_tr` e `camp_dpid_before_insert` replicadas (migração com backfill e `setval` no pico por conta; `open_conversation` lê via `RETURNING` com `read_after_writes`). Desvio deliberado: a BEFORE só preenche `display_id` NULL para preservar linhas restauradas fora de COPY; presença é `:body_unverified` no diff, corpo não verificável pelo catálogo. `campaigns_before_insert_row_tr` continua ausente com a tabela `campaigns`.

Limites: sem ensaio `pg_dump`/`pg_restore` integral deste lote; segredos restaurados continuam exigindo proteção antes do uso operacional; extensões `pgcrypto`/`vector`/`pg_stat_statements` seguem ausentes. Bootstrap Phoenix/Oban em banco restaurado e compatibilização da autenticação continuam pendentes. Rótulo de papel é `administrator` (igual ao Rails); transformações de mídia, `provider_config` local e Devise vazio→`nil` são decisões permanentes documentadas acima.

## Lote final recuperado e reproduzido em banco limpo

As migrations `20260927144424`–`20260927144428` (campanhas, Captain, monitores, Copilot e canais preservados) foram restauradas ao histórico versionado após terem sido revertidas sem remover seus efeitos dos bancos locais. Acrescentou-se `20260927151655` para `pgcrypto` e `pg_stat_statements`; `vector` já é habilitada pelo lote final e o Docker usa a imagem pgvector. São **25 tabelas de preservação de dados**, não funcionalidades ativadas. A comparação agora interpreta corretamente a FK implícita `inboxes` → `inbox_id` e remove apenas o wrapper `CHECK` fornecido por `pg_get_constraintdef`, com teste negativo para expressão alterada.

Prova atual: `mix ecto.create` → `mix ecto.migrate` → `mix chatwooter.schema_diff` em banco temporário limpo: 103/103 presentes, nenhuma diferença em tabelas, extensões upstream presentes. Suíte ExUnit em outro banco limpo: 382 testes passaram. O JSON medido está em `schema_parity_progress.json`. Não foi realizado nesta execução um ensaio de dump **real** de Chatwoot; os testes do lote usam dados sintéticos.

## Próximos desvios críticos

1. Bootstrap Phoenix/Oban, autenticação e ensaio com dump integral anonimizado; operação sandbox WA/TG e reconciliação de contagens, relações e sequências.
2. Comparar funções/semântica das quatro triggers com a origem; `conversations_before_insert_row_tr` deliberadamente mantém `display_id` explícito (ao contrário do Rails). `parity?` não representa aprovação operacional.
