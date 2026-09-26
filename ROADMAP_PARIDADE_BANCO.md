# Roadmap — paridade do banco Chatwoot → Chatwooter

Referência congelada: `chatwoot/db/schema.rb` (versão `2026_09_24_000000`) e os modelos/migrações em `chatwoot/` (**somente leitura**). Este plano substitui a estimativa superficial da “Fase A” do `ROTEIRO_ELIXIR.md`. A UI deixa de ser critério de avanço até o marco de dados abaixo.

## O que significa “1:1”

- **Paridade estrutural literal:** mesmas 103 tabelas do snapshot, com colunas, tipos PostgreSQL, precisão, nulidade, defaults, índices/uniques/checks, FKs e semântica dos enums documentados. Não basta criar uma tabela com o mesmo nome. Extensões exigidas pelo schema (por exemplo `pg_trgm`, `pgcrypto` e `vector`) entram no inventário; ativação depende de uso real e disponibilidade no ambiente alvo. Tabelas próprias Phoenix/Oban podem coexistir.
- **Paridade de dados:** um export da conta escolhida pode ser importado sem perder relações ou campos do escopo contratado; auditoria de contagens, checksums e amostras garante rastreabilidade. IDs novos são permitidos **somente com mapeamento explícito** de IDs originais; `conversations.display_id`, `messages.source_id` e `contact_inboxes.source_id` precisam manter seu significado.
- **Paridade operacional:** inboxes WhatsApp Cloud API e Telegram conseguem abrir, exibir e responder às conversas importadas. **Não** significa reproduzir Rails/Devise/ActiveStorage internamente, nem habilitar outros canais, campanhas ou Captain. Dados de canais não suportados devem continuar rastreáveis, mas não devem ser apresentados como operacionais.

Há uma decisão de arquitetura a validar **antes da implementação**: cumprir as 103 tabelas físicas do snapshot (inclusive módulos fora do v1), ou limitar a paridade física às tabelas usadas no corte WA/TG e preservar o restante em arquivo de importação. A segunda opção **não** é 1:1 estrutural literal. Este roadmap adota a primeira como meta solicitada e entrega os dados WA/TG primeiro; funcionalidades pós-v1 permanecem desligadas.

## Linha de base verificada

- `chatwoot/db/schema.rb`: **103** declarações `create_table`.
- `priv/repo/migrations/`: 12 tabelas criadas: **10 com nomes correspondentes** (`users`, `accounts`, `account_users`, `inboxes`, `contacts`, `contact_inboxes`, `conversations`, `messages`, `attachments`, `companies`) mais `users_tokens` e `oban_jobs` próprias. **10/103 não é porcentagem de paridade:** mesmo essas 10 têm diferenças de campos, tipos, defaults e índices.
- Divergências críticas: `conversations.display_id` ausente; `status` usa string aqui e enum inteiro no Chatwoot; `messages` não tem `sender_type`, `content_attributes` nem `external_source_ids`; `inboxes` guarda canal em `provider_config`, enquanto Chatwoot liga `channel_id`/`channel_type` às tabelas `channel_whatsapp` e `channel_telegram`; anexos usam `key`/`url` aqui e `external_url`/metadados + ActiveStorage no original; `users` usa autenticação Phoenix, não Devise. O índice único local em `contacts(account_id, phone_number)` também **não** equivale ao índice de telefone não único do snapshot; validar colisões reais antes de qualquer troca.
- Faltam por inteiro `teams`, `team_members`, `inbox_members`, `labels`, `tags`, `taggings`, `notes`, `canned_responses`, `notifications`, `notification_settings`, `access_tokens`, `webhooks` e as tabelas de canal, entre outras. Verificações de campos completas virão do diff automatizado, não desta lista exemplificativa.

## Sequência de execução (TDD em cada lote)

| Marco | Entrega | Critério de saída |
|---|---|---|
| **0 — Contrato e inventário** | Congelar commit/schema upstream; extrair catálogo por tabela (colunas/tipos/default/null/PK/FK/índices/checks/enums), dependências e dados sensíveis; classificar cada campo como `igual`, `transformado com teste`, `pendente` ou `fora do corte operacional`. Construir `mix chatwooter.schema_diff` comparando PostgreSQL **migrado** ao snapshot (não apenas structs Ecto). | Relatório versionado para as 103 tabelas; desvios conhecidos e transformações aprovados. Nenhum “✅” por mera existência de tabela. |
| **1 — Fundamentos e identidade** | Migrações incrementais para contas, usuários/membership e equipes (`teams`, `team_members`, `inbox_members`); mapear enums e credenciais de usuários sem copiar hashes Devise para login Phoenix; adicionar `import_mappings(account, table, old_id, new_id)` e trilha de erros/retomada. | Constraints, defaults, papéis e referências testados; importação de agentes idempotente e sem acesso cruzado entre contas. |
| **2 — CRM e canais** | Completar `contacts`, `contact_inboxes`, `companies`, `inboxes`; criar `channel_whatsapp`/`channel_telegram` ou justificar por contrato uma camada física equivalente (isso seria desvio da meta literal). Separar segredos criptografados de campos compatíveis importáveis. Completar `labels`, `tags`/`taggings`, `notes`, `canned_responses`, `working_hours`, `custom_attribute_definitions`. | Dados CRM e configurações WA/TG importados e consultáveis; uniques verificados com dados reais; nenhum token em texto puro. |
| **3 — Conversas, mensagens e mídia** | Adicionar `display_id` por conta (backfill + unique + sequência por conta), `contact_id`, assignee/time, prioridade, snooze, timestamps e JSONB; completar `messages` e enums; compatibilizar anexos e mapear blobs/URLs do ActiveStorage para storage próprio. Incluir `conversation_participants` e associações de etiquetas. | Histórico, notas privadas, autor, ordem, status e anexos preservados; chaves `source_id` idempotentes; sem colisões de `display_id`. |
| **4 — Plataforma e dados do corte** | Criar `access_tokens`, `webhooks`, `notifications`/settings, CSAT e tabelas auxiliares pertinentes; migrar campos necessários à API/webhooks Chatwoot sem supor que igualdade de schema garante igualdade de payload. | Export/import de uma conta WA+TG com relatório por tabela, contagens e amostras reconciliadas; abre e responde em sandbox. |
| **5 — Cobertura estrutural integral** | Criar as demais tabelas do snapshot por grupos de dependência (canais não suportados, Rails/ActiveStorage, relatórios/SLA, campanhas, automações, help center, integrações, Captain/AI). Definir claramente quais são apenas preservação de dados e quais têm implementação ativa; validar extensões e tipos especiais. | `schema_diff` com zero diferenças **não justificadas** nas 103 tabelas e seus constraints/índices. Uma exceção documentada continua impedindo alegar “literalmente idêntico”. |
| **6 — Prova de migração e corte** | Importador dry-run, reexecução idempotente, reconciliação de dados de amostras de produção anonimizadas, testes de rollback e guia de freeze/cutover WA+TG. Não instalar webhooks externos durante dry-run. | 2 importações seguidas não duplicam registros; contagens e relações batem; conversa e resposta reais nos dois canais; relatório explícito dos canais não ativados. |

## Regras de implementação

1. Escrever teste primeiro para cada lote: migração em banco limpo **e** banco já populado, constraints, enums, FKs, backfill, conta cruzada e reimportação. Usar `mix ecto.gen.migration nome_da_migracao`; não reescrever migrações já aplicadas.
2. Preservar a direção dos contexts (`Channels → Conversations → Contacts → Inboxes → Accounts`), sem `ChatwooterWeb → Repo`. O importador lê a origem em conexão read-only, grava pelos contexts/serviços de importação e guarda correspondências por conta/tabela/ID.
3. Tratar `created_at/updated_at` ↔ `inserted_at/updated_at`, inteiros de enums Rails ↔ representação Ecto, `serial` ↔ `bigint`, JSONB, polimorfismo e ActiveStorage como **transformações testadas**, nunca como igualdade implícita.
4. Antes de `NOT NULL`/unique em banco existente: detectar conflitos → corrigir/backfill em lotes → adicionar constraint. Evitar lock longo em produção; testar rollback sempre que possível.
5. Segredos da Meta/Telegram jamais copiados em texto puro para `provider_config`; importação criptografa, mascara logs e compara apenas identificadores não sensíveis.
6. `mix precommit` verde é condição para cada lote. Se o baseline impedir, corrigir/registrar bloqueio de qualidade separadamente, sem mascarar falhas do novo schema.

## Ordem de prioridade e tamanho

**P0:** marcos 0–3 (modelo de dados para histórico e operação WA/TG). **P1:** marcos 4 e 6 (migração utilizável). **P2 obrigatório para reivindicar 1:1 literal:** marco 5. Não prometer prazo antes do inventário do marco 0: criar 93 tabelas ausentes com constraints e validar export real é substancialmente maior do que a antiga estimativa de “Fase A: 1 semana”.

**Próxima tarefa executável:** produzir o catálogo comparativo e um teste de contrato do `schema_diff` para `accounts`, `inboxes`, `contacts`, `conversations` e `messages`, sem aplicar ainda migrações destrutivas.
