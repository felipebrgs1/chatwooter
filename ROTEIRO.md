# Roteiro: Chatwooter — 1:1 com o Chatwoot e migrável

> Objetivo: reconstruir o Chatwoot (v4.18, referência em `chatwoot/`) como **API Go (MVC) + dashboard React**,
> **1:1 no escopo WhatsApp + Telegram**, permitindo **migração de conta do Chatwoot para cá**
> (dados + integrações continuam funcionando). UI portada 1:1 dos `.vue` do Chatwoot.
>
> A primeira versão foi escrita em Elixir/Phoenix LiveView e substituída pela stack atual
> (ver [`ROADMAP_MIGRACAO_GO_REACT.md`](./ROADMAP_MIGRACAO_GO_REACT.md)); o código antigo está na tag `elixir-final`.

> **Status da paridade:** [produto/UI](./ROADMAP_PARIDADE_PRODUTO.md) e [banco ✅](./docs/SCHEMA_PARITY.md). As fases abaixo descrevem o produto planejado, não uma declaração de conclusão.

## Decisões travadas (revisão 2026-09-26)

1. **Canais: só WhatsApp Cloud API + Telegram Bot API.** Email, Instagram, Facebook, X, TikTok, Line,
   SMS, webchat e demais **não serão implementados** — o importador os reporta como não suportados
   (conta migra, inboxes desses canais vêm como `disabled` + relatório).
2. **IDs na migração: novos + mapa de correspondência.** Nada de preservar PKs (arriscado com FKs e
   sequences). Tabela local `import_mappings(account_id, source_table, old_id, new_id)` + preservação
   semântica onde importa: `conversations.display_id` (o "#123" visível), `messages.source_id`
   (wamid), `contact_inboxes.source_id`.
3. **"Pronto" = conta migrada abre, conversa e responde.** Relatórios, macros, automações, campanhas
   e help-center vêm depois do corte de migração.
4. **Compat de integração:** API REST v1 e webhooks de saída usam **os mesmos formatos do Chatwoot**
   (rotas, JSON, nomes de eventos). Integração existente aponta para cá sem mudar código.

---

## 1. Visão e Escopo

### 1.1. v1.0 — paridade migável (WA + Telegram)
- Multi-conta, agentes (nome, papel, disponibilidade), times, inbox_members, inboxes WA/TG completos.
- Contatos, empresas, contact_inboxes, labels, canned e notas (contrato de campos no roadmap do banco).
- Conversas, mensagens, anexos e CSAT simples (desvios de schema medidos pelo `schemadiff` (Go)).
- Canais WA + Telegram fim-a-fim (texto + mídia + receipts WA + templates/regra 24h).
- Tempo real (WebSocket `/cable` + presença), notificações sino, webhooks de saída + API v1 no formato Chatwoot.
- Importador Chatwoot → Chatwooter + guia de cutover.

### 1.2. Fora do escopo (importador reporta, não implementa)
- Outros canais, campanhas (bulk), portais/help-center, AgentBot/LLM, relatórios avançados,
  Slack/Linear/Shopify e demais integrações, apps de plataforma, audit log avançado.
- Pós-v1: macros, automation_rules, CSAT completo, snooze avançado, relatórios.

---

## 2. Paridade do banco (Chatwoot 4.18 → Chatwooter)

✅ Paridade estrutural concluída e travada pelo gate `TestMigratedDatabaseMatchesUpstreamSnapshot`; o que ele cobre, as decisões de leitura dos dados Rails e as regras para mudar o schema estão em [`docs/SCHEMA_PARITY.md`](./docs/SCHEMA_PARITY.md). Para medir outro banco migrado, usar `make schema-diff`.

Canais não suportados ainda precisam ser preservados e relatados; isso **não** está implementado pela importação atual de agentes.

---

## 3. Stack (travada)

| Camada | Escolha |
|---|---|
| API | Go + `chi`, MVC (`router → controllers → models`, JSON em `views`), `slog` |
| Banco | Postgres 18 (pgvector) com o schema idêntico ao `schema.rb` do Chatwoot; `goose` + `sqlc` (pgx) |
| Jobs | River (Sidekiq → filas `webhook_ingest`, `senders`, `outgoing_webhooks`, `notifications`, `maintenance`, `import`) |
| Auth | cookie de sessão `HttpOnly` no dashboard (bcrypt do Devise); API v1 por `api_access_token`, como o Chatwoot |
| Dashboard | React + TypeScript + Vite, TanStack Router/Query, Tailwind v4, i18n do Chatwoot (en, pt_BR), ícones Phosphor |
| Canais | interface `channels.Channel` (HTTP com Meta/Telegram só via jobs); segredos AES-GCM (`models.InboxConfigs`) |
| Testes | `go test` com Postgres real descartável por teste (`internal/testdb`, `internal/factory`); Vitest + Testing Library + MSW |
| Qualidade | `make precommit` (fmt, golangci-lint, eslint, typecheck, testes) verde antes de cada push |

---

## 4. Arquitetura

```
server/                     # API Go
  internal/router           # rotas (a API do Chatwoot: mesmos caminhos e JSON)
  internal/controllers      # HTTP: lê a requisição, chama models, responde com views
  internal/models           # regras e acesso a dados (único pacote que usa o código do sqlc)
  internal/views            # serialização (espelha os .jbuilder do Chatwoot)
  internal/db               # migrations goose + queries sqlc
  internal/jobs             # workers River (todo efeito externo)
web/                        # dashboard React (rota = arquivo em src/routes)
```

Direção imposta pelo `depguard`: controller nunca importa `pgx`/`db`; model nunca importa `net/http`;
view só serializa tipos dos models. O importador lê o PG do Chatwoot (**só leitura**, outra conexão)
e escreve pelos models.

---

## 5. TDD + Clean Code (operar todo dia)

1. **Red:** teste falhando (`*_test.go` ao lado do código, com `internal/factory`; ou `*.test.tsx` com Testing Library).
2. **Green:** implementação mínima.
3. **Refactor:** `make precommit` verde.
- Erros de domínio são valores (`models.ErrNotFound`...), nunca `panic` em fluxo normal.
- `provider_config` com segredos cifrados; efeitos colaterais só via River.

---

## 6. UI equivalente ao Chatwoot (React)

Ordem de fidelidade: Conversations (3 colunas) → Contacts (cards + detalhe) → Companies →
Agents (modal) → Settings/inboxes → Teams/Labels/Canned/Notes → Reports (pós-v1).
Referência de cada tela: `chatwoot/app/javascript/dashboard/...` (nunca editar).

---

## 7. WhatsApp (Cloud API oficial) e Telegram (Bot API via webhook)

Mantido do roteiro anterior: verify + ingest async (<500ms) + mídia via storage + sender no River +
receipts (WA) + templates/regra 24h (WA) + `setWebhook` com secret (TG).
Nenhum dos dois canais existe ainda na stack Go: a implementação Elixir (Telegram parcial) ficou na tag
`elixir-final` e serve de referência para o port.

---

## 8. Trilha de migração (o diferencial deste roteiro)

### 8.1. Importador completo (planejado; o comando ainda não existe)
Ordem (respeita FKs): account → users → teams → inboxes (WA/TG; resto `unsupported`) →
labels → contacts → companies (+link) → contact_inboxes → conversations (**preserva `display_id`**,
recalcula sequência) → messages (**preserva `source_id`** p/ idempotência) → attachments (re-host ou
copia URL) → canned/notes/notifications-settings.
- Roda no River (fila `import`), idempotente (re-run retoma por `import_mappings`), dry-run com relatório
  (contagens por tipo + canais ignorados).
- Mídia: tenta baixar do Chatwoot e re-hospedar no nosso storage; fallback mantém URL externa.

### 8.2. Compat de API e webhooks
- `POST /api/v1/...` com mesmos paths e JSON do Chatwoot (conversations, messages, contacts...).
- Webhooks de saída: mesmos eventos (`conversation_created`, `message_created`, ...) e HMAC.
- Teste de contrato: fixtures de payload real do Chatwoot comparados campo a campo.

### 8.3. Cutover
Guia: freeze → export → import → valida contagens → troca DNS/webhooks Meta-TG → dual-run 48h →
desliga. Rollback = voltar webhooks (dados novos ficam só aqui; documentar).

---

## 9. Fases (com status real e DoD)

O andamento detalhado (fundação, autenticação, casca, conversas) está no
[`ROADMAP_MIGRACAO_GO_REACT.md`](./ROADMAP_MIGRACAO_GO_REACT.md).

### Fase 0 — Fundação ✅ feito (Go + React, schema paritário, gate `make precommit`)
### Fase 1 — Núcleo 🟡 parcial (login, casca, lista e conversa aberta; tempo real pendente)
### Fase 2 — Telegram ❌ pendente na stack Go
- Webhook com secret, ingest assíncrono, todos os tipos (§7), `sendMessage/Photo/Document/Voice`.
- **DoD:** conversa real texto+foto+áudio <3s nos dois sentidos.

### Fase 3 — WhatsApp ❌ pendente
- Adapter CloudApi + verify + ingest + mídia + receipts + templates + regra 24h + settings.
- **DoD:** mesmo do Telegram + template fora da janela + receipts na UI.

### Fase A — Paridade de banco ✅
- Schema 1:1 com o Chatwoot 4.18 (103 tabelas, triggers, extensões), travado pelo gate; ver [`docs/SCHEMA_PARITY.md`](./docs/SCHEMA_PARITY.md).

### Fase B — CRM faltante ❌
- Teams, labels, canned (`/` no composer), notas, sino de notificações + UI.
- **DoD:** fluxo de suporte completo (atribuir time, etiquetar, canned, nota privada).

### Fase D — Plataforma compat ❌
- Webhooks de saída + API v1 no formato Chatwoot + testes de contrato.
- **DoD:** script de integração feito p/ Chatwoot roda aqui sem alteração.

### Fase E — Importador + cutover ❌
- §8 inteiro. **DoD:** conta real do Chatwoot (WA+TG) migrada abre, conversa e responde.

### Fase F — Pós-migração (backlog)
macros, automation_rules, campanhas, CSAT completo, relatórios, help-center, avatar de empresa,
outros canais (só se um dia sair do corte).

Não há estimativa confiável até concluir o inventário de transformações e ensaiar um export anonimizado (ver roadmap de banco).

---

## 10. Backlog priorizado

```
P0: paridade do banco (marcos 0–3), seguida dos bloqueios operacionais Telegram/WhatsApp
P1: Fase B (teams/labels/canned/notas/notificações), Fase D (API+webhooks compat)
P1: Fase E (importador + cutover)
P2: snooze, CSAT completo, inbox settings avançados (horários, auto-assignment)
PÓS: macros, automações, campanhas, relatórios, help-center, outros canais
```

---

## 11. Riscos

1. **Meta muda API/tokens expiram** → client versionado + isolamento no adapter.
2. **Re-tentativas de webhook** → idempotência por `source_id` + jobs únicos do River (vale p/ importador re-run).
3. **Divergência de formato** → testes de contrato com fixtures reais do Chatwoot (API + webhooks + import).
4. **Mídia órfã na migração** → fallback URL externa + relatório de pendências.
5. **Multitenancy** → `account_id` em toda query; import sempre escopado por conta.
