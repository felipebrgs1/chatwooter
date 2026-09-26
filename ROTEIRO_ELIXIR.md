# Roteiro: Chatwooter em Elixir + Phoenix — 1:1 com o Chatwoot e migrável

> Objetivo: reconstruir o Chatwoot (v4.18, referência em `chatwoot/`) como **monolito modular em Phoenix**,
> **1:1 no escopo WhatsApp + Telegram**, permitindo **migração de conta do Chatwoot para cá**
> (dados + integrações continuam funcionando). UI equivalente ao Chatwoot via LiveView.

> **Prioridade atual:** [roadmap de paridade do banco](./ROADMAP_PARIDADE_BANCO.md). A Fase A abaixo é um resumo histórico; o novo roadmap detalha as 103 tabelas e os critérios para afirmar paridade 1:1.

## Decisões travadas (revisão 2026-09-26)

1. **Canais: só WhatsApp Cloud API + Telegram Bot API.** Email, Instagram, Facebook, X, TikTok, Line,
   SMS, webchat e demais **não serão implementados** — o importador os reporta como não suportados
   (conta migra, inboxes desses canais vêm como `disabled` + relatório).
2. **IDs na migração: novos + mapa de correspondência.** Nada de preservar PKs (arriscado com FKs e
   sequences). Tabela `import_mappings(chatwoot_type, chatwoot_id, chatwooter_id)` + preservação
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
- Contatos (todos os campos §2), empresas, contact_inboxes, labels, canned, notas.
- Conversas + mensagens + anexos (todos os campos §2), CSAT simples.
- Canais WA + Telegram fim-a-fim (texto + mídia + receipts WA + templates/regra 24h).
- Tempo real (PubSub + Presence), notificações sino, webhooks de saída + API v1 no formato Chatwoot.
- Importador Chatwoot → Chatwooter + guia de cutover.

### 1.2. Fora do escopo (importador reporta, não implementa)
- Outros canais, campanhas (bulk), portais/help-center, AgentBot/LLM, relatórios avançados,
  Slack/Linear/Shopify e demais integrações, apps de plataforma, audit log avançado.
- Pós-v1: macros, automation_rules, CSAT completo, snooze avançado, relatórios.

---

## 2. Matriz de paridade (Chatwoot 4.18 → Chatwooter)

Legenda: ✅ existe · 🟡 parcial · ❌ falta. "Falta" em *schema* bloqueia migração.

### 2.1. Tabelas que já existem

| Tabela | Status | Campos faltantes p/ 1:1 |
|---|---|---|
| `accounts` | 🟡 | `support_email`, `auto_resolve_*`, `limits`, `locale` checar |
| `users` | ✅ | — (name, availability via membership; 2FA/SSO pós-v1) |
| `account_users` | ✅ | — |
| `teams` / `team_members` | ❌ | tabela inteira |
| `inboxes` | 🟡 | `sender_name_type`, `working_hours*`, `csat_*`, `greeting_enabled`, `auto_assignment*`, `timezone`, `lock_to_single_conversation`, `out_of_office_message` |
| `inbox_members` | ❌ | tabela inteira |
| `contacts` | 🟡 | `identifier` (+unique/acct), `blocked`, `country_code`, `location`, `city`, `last_name`, `middle_name`, `last_activity_at`, `custom_attributes`, uniques de email/telefone por conta |
| `contact_inboxes` | ✅ | — (checar `hmac_verified`, `pubsub_token`) |
| `companies` | 🟡 | avatar (pós-v1), `last_activity_at` (derivado do histórico no MVP) |
| `conversations` | 🟡 | **`display_id`** (obrigatório p/ migração), `priority`, `snoozed_until`, `waiting_since`, `first_reply_created_at`, `identifier`, `uuid`, `custom_attributes`, `contact_id` direto |
| `messages` | 🟡 | `content_attributes`, `external_source_ids`, `sender_type`, `sentiment`, `processed_message_content` |
| `attachments` | 🟡 | checar `extension`, `fallback_title`, `meta` vs nosso `metadata` |
| `labels` (+ joins) | ❌ | tabelas inteiras (`labels`, `taggings`-like) |
| `canned_responses` | ❌ | tabela inteira |
| `notes` | ❌ | tabela inteira |
| `notifications` (+ settings) | ❌ | tabelas inteiras |
| `webhooks` (saída) | ❌ | tabela inteira |
| `access_tokens` | ❌ | tabela inteira (auth da API v1) |

### 2.2. Domínios novos p/ migração
- `import_mappings` (tipo, id_origem, id_destino, conta) + `mix chatwooter.import_from_chatwoot`.
- Canais não suportados: inbox importada como `channel_type: :unsupported` + `provider_config.migration_note`
  (nunca quebra a conta; UI mostra aviso).

---

## 3. Stack (travada)

| Camada | Escolha |
|---|---|
| Elixir 1.20 + Phoenix 1.8 + LiveView 1.2 | realtime nativo |
| Postgres 16 + Ecto | mesmos tipos do Chatwoot (JSONB) |
| Oban | Sidekiq → filas `webhook_ingest`, `senders`, `outgoing_webhooks`, `notifications`, `maintenance`, `import` |
| Auth dashboard | `phx.gen.auth` (session); API v1 por `access_tokens` (Bearer, como o Chatwoot) |
| HTTP externo | **`Req`** (não Tesla/HTTPoison) atrás do Behaviour `Chatwooter.Channels.Channel` |
| Testes | ExUnit + Ecto Sandbox + ExMachina + Mox (+ Bypass p/ Meta/Telegram) |
| Qualidade | `mix precommit` verde antes de cada push |

---

## 4. Arquitetura: Monolito Modular

```
lib/chatwooter/  accounts/ inboxes/ contacts/ conversations/ companies/
                 channels/ (behaviour + whatsapp/ telegram/)
                 labels/ canned/ teams/ notes/ notifications/ platform/ imports/
ChatwooterWeb → Contexts (nunca Web → Repo direto)
```

Direção: `Channels -> Conversations -> Contacts -> Inboxes -> Accounts`.
`Imports` lê o PG do Chatwoot (**só leitura**, outra conexão) e escreve via **funções públicas** dos contexts.

---

## 5. TDD + Clean Code (operar todo dia)

1. **Red:** teste falhando em `test/chatwooter/*_test.exs` com factories, sem tocar em `lib/`.
2. **Green:** implementação mínima no context.
3. **Refactor:** `mix precommit` (format + test + credo...) verde.
- Contexts retornam `{:ok, _} | {:error, changeset}` — nunca raise em fluxo normal.
- `provider_config` com segredos; efeitos colaterais só via Oban.

---

## 6. UI equivalente ao Chatwoot (LiveView)

Ordem de fidelidade: Conversations (3 colunas) → Contacts (cards + detalhe) → Companies →
Agents (modal) → Settings/inboxes → Teams/Labels/Canned/Notes → Reports (pós-v1).
Referência de cada tela: `chatwoot/app/javascript/dashboard/...` (nunca editar).

---

## 7. WhatsApp (Cloud API oficial) e Telegram (Bot API via webhook)

Mantido do roteiro anterior: verify + ingest async (<500ms) + mídia via storage + sender Oban +
receipts (WA) + templates/regra 24h (WA) + `setWebhook` com secret (TG).
Telegram pendente: `edited_message`, `callback_query`, `channel_post`, voz/áudio/doc/sticker/location,
`sendPhoto/sendDocument/sendVoice`.

---

## 8. Trilha de migração (o diferencial deste roteiro)

### 8.1. Importador (`mix chatwooter.import_from_chatwoot --database URL --account ID`)
Ordem (respeita FKs): account → users → teams → inboxes (WA/TG; resto `unsupported`) →
labels → contacts → companies (+link) → contact_inboxes → conversations (**preserva `display_id`**,
recalcula sequência) → messages (**preserva `source_id`** p/ idempotência) → attachments (re-host ou
copia URL) → canned/notes/notifications-settings.
- Roda em Oban (`import` queue), idempotente (re-run retoma por `import_mappings`), dry-run com relatório
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

### Fase 0 — Fundação ✅ feito
### Fase 1 — Núcleo ✅ feito (conversas, PubSub, dashboard 3 colunas)
### Fase 2 — Telegram 🟡 parcial
- Falta: tipos restantes (§7) + `sendPhoto/Document/Voice`.
- **DoD:** conversa real texto+foto+áudio <3s nos dois sentidos.

### Fase 3 — WhatsApp ❌ próxima
- Adapter CloudApi + verify + ingest + mídia + receipts + templates + regra 24h + settings.
- **DoD:** mesmo do Telegram + template fora da janela + receipts na UI.

### Fase A — Paridade de schema ❌ (desbloqueia migração)
- Campos §2.1 nas tabelas existentes + `teams`, `inbox_members`, `labels`, `canned_responses`, `notes`,
  `notifications`, `webhooks`, `access_tokens`, `import_mappings`.
- **DoD:** `mix chatwooter.schema_diff` (a criar) lista zero campos obrigatórios faltantes.

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

Estimativa (1 dev): A 1 sem · B 2 sem · 3 (WA) 3 sem · D 2 sem · E 2 sem → **~10 sem p/ migração funcionando**.

---

## 10. Backlog priorizado

```
P0: Fase 2 (resto Telegram), Fase 3 (WhatsApp), Fase A (schema)
P1: Fase B (teams/labels/canned/notas/notificações), Fase D (API+webhooks compat)
P1: Fase E (importador + cutover)
P2: snooze, CSAT completo, inbox settings avançados (horários, auto-assignment)
PÓS: macros, automações, campanhas, relatórios, help-center, outros canais
```

---

## 11. Riscos

1. **Meta muda API/tokens expiram** → client versionado + isolamento no adapter.
2. **Re-tentativas de webhook** → idempotência por `source_id` + Oban unique (vale p/ importador re-run).
3. **Divergência de formato** → testes de contrato com fixtures reais do Chatwoot (API + webhooks + import).
4. **Mídia órfã na migração** → fallback URL externa + relatório de pendências.
5. **Multitenancy** → `account_id` em toda query; import sempre escopado por conta.
