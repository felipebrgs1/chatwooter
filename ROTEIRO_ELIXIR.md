# Roteiro: Chatwooter em Elixir + Phoenix — 1:1 com o Chatwoot e migrável

> Objetivo: reconstruir o Chatwoot (v4.18, referência em `chatwoot/`) como **monolito modular em Phoenix**,
> **1:1 no escopo WhatsApp + Telegram**, permitindo **migração de conta do Chatwoot para cá**
> (dados + integrações continuam funcionando). UI equivalente ao Chatwoot via LiveView.

> **Status da paridade:** [produto/UI](./ROADMAP_PARIDADE_PRODUTO.md), [banco](./ROADMAP_PARIDADE_BANCO.md) e [estado medido](./docs/SCHEMA_PARITY.md). As fases abaixo descrevem o produto planejado, não uma declaração de conclusão.

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
- Tempo real (PubSub + Presence), notificações sino, webhooks de saída + API v1 no formato Chatwoot.
- Importador Chatwoot → Chatwooter + guia de cutover.

### 1.2. Fora do escopo (importador reporta, não implementa)
- Outros canais, campanhas (bulk), portais/help-center, AgentBot/LLM, relatórios avançados,
  Slack/Linear/Shopify e demais integrações, apps de plataforma, audit log avançado.
- Pós-v1: macros, automation_rules, CSAT completo, snooze avançado, relatórios.

---

## 2. Paridade do banco (Chatwoot 4.18 → Chatwooter)

Não manter uma segunda matriz manual de ✅/❌: existência não prova igualdade. O [inventário inicial congelado e o estado atual](./docs/SCHEMA_PARITY.md) distinguem tabelas presentes, desvios de campos/constraints, importação de agentes já testada e trabalho restante. Para medir outro banco migrado, usar `make schema-diff`. A meta de 103 tabelas e os critérios de saída estão no [roadmap do banco](./ROADMAP_PARIDADE_BANCO.md).

Canais não suportados ainda precisam ser preservados e relatados; isso **não** está implementado pela importação atual de agentes.

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

### 8.1. Importador completo (planejado; o comando ainda não existe)
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

### Fase 3 — WhatsApp ❌ pendente
- Adapter CloudApi + verify + ingest + mídia + receipts + templates + regra 24h + settings.
- **DoD:** mesmo do Telegram + template fora da janela + receipts na UI.

### Fase A — Paridade de banco 🟡 (em andamento)
- `schemadiff` (Go), equipes/vínculos e importação limitada de agentes já existem; ver [estado medido](./docs/SCHEMA_PARITY.md).
- **DoD:** marcos 0–6 do [roadmap de banco](./ROADMAP_PARIDADE_BANCO.md), com export reconciliado; um diff vazio isolado não comprova paridade.

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
2. **Re-tentativas de webhook** → idempotência por `source_id` + Oban unique (vale p/ importador re-run).
3. **Divergência de formato** → testes de contrato com fixtures reais do Chatwoot (API + webhooks + import).
4. **Mídia órfã na migração** → fallback URL externa + relatório de pendências.
5. **Multitenancy** → `account_id` em toda query; import sempre escopado por conta.
