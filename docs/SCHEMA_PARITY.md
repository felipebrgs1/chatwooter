# Paridade do banco — estado e pendências

## Referência e medição

- Origem somente leitura: `chatwoot/db/schema.rb`, versão `2026_09_24_000000`, commit upstream `845206aa6fd053998cfb153884afc2f464904e40` (SHA-256 `128ffd15948a3d9dac6ab68185f7742de3ddc40f61a20474de038faa4f3246cc`).
- `schema_parity_baseline.json` permanece como relatório histórico inicial de 10 tabelas. O parser antigo interpretava strings Rails sem limite como varchar(255); o comparador agora usa varchar sem limite, conforme o [adapter PostgreSQL Rails 7.2.3.1](https://github.com/rails/rails/blob/v7.2.3.1/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb). O baseline não foi sobrescrito.
- Banco migrado após o lote CRM: **18/103 tabelas presentes, 85 ausentes**. Presença não significa paridade integral; `parity?` continua `false`. Tabelas Phoenix/Oban e helpers históricos de importação são extras locais.

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

## Próximos desvios críticos

1. `contacts`, `contact_inboxes`, `companies`: colunas, timestamps, defaults e índices. A unique local de telefone por conta difere da origem; não tratar telefone como identidade única implícita.
2. Inboxes/canais: `channel_id`, nomes polimórficos Rails, tabelas WA/TG e proteção de segredos antes da operação.
3. Conversas/mensagens: `display_id`, sequência/trigger por conta, enums inteiros, autor polimórfico, JSON e anexos/ActiveStorage.
4. Bootstrap Phoenix/Oban, autenticação e ensaio com dump integral anonimizado; operação sandbox WA/TG e reconciliação de contagens, relações e sequências.
5. As 85 tabelas ausentes e as diferenças das tabelas já presentes impedem alegar paridade literal 1:1.
