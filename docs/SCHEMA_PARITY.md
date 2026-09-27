# Paridade do banco — estado e pendências

## Referência e medição

- Origem somente leitura: `chatwoot/db/schema.rb`, versão `2026_09_24_000000`, commit upstream `845206aa6fd053998cfb153884afc2f464904e40` (SHA-256 `128ffd15948a3d9dac6ab68185f7742de3ddc40f61a20474de038faa4f3246cc`).
- `schema_parity_baseline.json` permanece como relatório histórico inicial de 10 tabelas. O parser antigo interpretava strings Rails sem limite como varchar(255); o comparador agora usa varchar sem limite, conforme o [adapter PostgreSQL Rails 7.2.3.1](https://github.com/rails/rails/blob/v7.2.3.1/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb). O baseline não foi sobrescrito.
- Banco migrado após os lotes CRM, plataforma e preservação/canais: **58/103 tabelas presentes, 45 ausentes; 45 equivalentes no catálogo físico**. Presença não significa paridade integral; `parity?` continua `false`. Tabelas Phoenix/Oban e helpers históricos de importação são extras locais.

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
- Catálogo atual: 58 tabelas upstream presentes, 45 iguais fisicamente, 13 ainda diferentes e 45 ausentes. Progresso medido em `schema_parity_progress.json`; baseline inicial permanece congelado.

Limites: ActiveStorage conserva metadados/relações, mas não transfere arquivos binários. SAML, políticas de capacidade, email Rails e importações upstream não foram ativados. As tabelas de canais preservam o formato original; não são usadas pelos adapters atuais e não resolvem `inboxes.channel_id/channel_type`. Redação de certificados/tokens/config na inspeção não criptografa segredos restaurados: a proteção e compatibilização antes de uso operacional continuam pendentes. Não foram criadas UI/rotas, jobs de importação ou webhooks externos. Captain não foi incluído neste lote.

## Próximos desvios críticos

1. `contacts`, `contact_inboxes`, `companies`: colunas, timestamps, defaults e índices. A unique local de telefone por conta difere da origem; não tratar telefone como identidade única implícita.
2. Inboxes/canais: `channel_id`, nomes polimórficos Rails, tabelas WA/TG e proteção de segredos antes da operação.
3. Conversas/mensagens: `display_id`, sequência/trigger por conta, enums inteiros, autor polimórfico, JSON e anexos/ActiveStorage.
4. Bootstrap Phoenix/Oban, autenticação e ensaio com dump integral anonimizado; operação sandbox WA/TG e reconciliação de contagens, relações e sequências.
5. As 45 tabelas ausentes e as diferenças das tabelas já presentes impedem alegar paridade literal 1:1.
