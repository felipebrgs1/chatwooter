# Roteiro: Chatwoot Refatorado em Elixir + Phoenix — Foco WhatsApp + Telegram

> Objetivo: reconstruir o essencial do Chatwoot (v4.18) como **monolito modular em Phoenix**, com **TDD + Clean Code**, cobrindo só **WhatsApp e Telegram** no início, com **UI idêntica** ao Chatwoot.

---

## 1. Visão e Escopo

### 1.1. O que é MVP (v0.1 – v1.0)
- Multi-conta (Account), usuários + papéis (admin/agent), login, times e inboxes.
- Contatos + ContactInboxes + Conversas + Mensagens + Anexos.
- Canais: **WhatsApp Cloud API (oficial Meta)** + **Telegram Bot API**. Só texto + mídia básica no MVP.
- Inbox unificada: lista de conversas, filtros (aberta/pendente/resolvida/minhas), atribuição, notas internas.
- Tempo real: nova mensagem aparece sem refresh, digitação e presença.
- Webhooks de saída + API REST mínima compatível com Chatwoot.
- Canned responses, labels, CSAT simples.

### 1.2. Fora do escopo inicial (ignorar de propósito)
- Email, Instagram, Facebook, X/Twitter, TikTok, Line, SMS/Twilio, voz, campanhas SMS, portais/help-center, apps de plataforma, Slack/Linear/Shopify, bots AgentBot complexos, relatórios avançados.
- Deixe **slots de extensão** para eles, mas não implemente.

### 1.3. Princípio de corte
Se uma feature do Chatwoot não serve WhatsApp/Telegram, ela entra no backlog `pós-v1` e o schema nem é criado agora.

---

## 2. Stack Definida (trave isso no dia 1)

| Camada | Escolha | Por quê |
|---|---|---|
| Linguagem/Framework | **Elixir 1.17+ + Phoenix 1.8 + LiveView 1.0** | Produtividade + realtime nativo, substitui ActionCable+Vue |
| DB | **Postgres 16 + Ecto** | Igual Chatwoot, JSONB para `additional_attributes` |
| Jobs | **Oban** | Substitui Sidekiq |
| Realtime | **Phoenix.PubSub + Presence** | Substitui ActionCable |
| Auth | **phx.gen.auth (session) + Guardian/JWT p/ API** | Dashboard + API/integrações |
| Front | **LiveView + TailwindCSS + Alpine.js** | Replica UI Chatwoot sem manter SPA Vue gigante |
| HTTP externo | **Tesla + Finch** | Clients WhatsApp/Telegram mockáveis |
| Testes | **ExUnit + Mox + ExMachina + Wallaby (só fluxos críticos)** | TDD padrão |
| Lint/format | **mix format + Credo + Dialyxir + Sobelow** | Clean Code automatizado |
| Observabilidade | **Telemetry + PromEx + Sentry** | — |
| Deploy | **Docker + mix release, Fly.io ou Hetzner + Caddy** | Simples; Postgres + Redis (p/ Oban/Presence cluster) |
| i18n | **Gettext (pt-BR primeiro, en segundo)** | Chatwoot é multi-idioma |

> Alternativa consciente: se seu time é forte em Vue, faça **Phoenix API-only + Vue 3** copiando os componentes `dashboard/` do Chatwoot. É mais fiel visualmente, porém 2x mais trabalho. Recomendação deste roteiro: **LiveView primeiro**, extraia API REST em paralelo.

Instalação base (você está sem Elixir instalado):
```bash
# via asdf ou mise
mise install elixir@1.17.3 erlang@27.0
mix local.hex --force; mix archive.install hex phx_new --force
mix phx.new chatwooter --live --database postgres --tailwind --gettext
cd chatwooter
mix deps.get && mix ecto.setup
mix phx.server
```

---

## 3. Arquitetura: Monolito Modular (a parte mais importante)

### 3.1. Regra de ouro
Um único deploy, vários **Bounded Contexts** isolados. Nenhum context acessa repo/schema de outro diretamente — só via **função pública do context**.

```
lib/
  chatwooter/               # domínio puro (sem Phoenix)
    accounts/               # Account, User, AccountUser, Team, TeamMember
    contacts/               # Contact, ContactInbox, Note, Label
    inboxes/                # Inbox, InboxMember, Channel config
    conversations/          # Conversation, Message, Attachment, Participant, CannedResponse
    channels/               # Behaviour + adapters
      whatsapp/
      telegram/
    automations/            # AutomationRule, Macro (pós-MVP)
    notifications/          # Notification, NotificationSetting
    platform/               # Webhooks saída, API tokens
  chatwooter_web/           # só HTTP/LiveView — fino, sem regra de negócio
    live/
      inbox_live/
      conversation_live/
      contacts_live/
      settings_live/
    controllers/api/v1/
    channels/               # UserSocket, Presence
  chatwooter/workers/       # Oban workers (um por efeito colateral)
```

Dependências permitidas (direção única):
```
Channels -> Conversations -> Contacts -> Inboxes -> Accounts
Workers -> Channels + Conversations
Web -> Contexts (nunca Web -> Repo direto)
```

Enforce com `mix boundaries` (biblioteca `Boundaries`) ou teste de arquitetura:
```elixir
# test/architecture_test.exs
test "contexts não vazam Ecto" do
  refute "ChatwooterWeb" |> code() |> invokes?(Chatwooter.Repo)
end
```

### 3.2. Bounded Contexts (mapeado do Rails original)

| Context | Schemas (Ecto) | Responsabilidade |
|---|---|---|
| `Accounts` | `accounts`, `users`, `account_users(role)`, `teams`, `team_members` | tenant, auth, RBAC |
| `Inboxes` | `inboxes(channel_type, provider_config jsonb)`, `inbox_members` | caixa de entrada por canal |
| `Contacts` | `contacts`, `contact_inboxes`, `notes`, `labels`, `contact_labels` | CRM mínimo |
| `Conversations` | `conversations(status, priority, assignee)`, `messages(content, content_type, status, source_id)`, `attachments`, `conversation_participants`, `canned_responses` | coração do app |
| `Channels.WhatsApp` | sem tabela própria, usa `inboxes.provider_config` | enviar/receber via Cloud API |
| `Channels.Telegram` | idem | enviar/receber via Bot API |
| `Notifications` | `notifications`, `notification_settings` | sino + email digest |
| `Platform` | `webhooks`, `access_tokens` | integrações saída |

### 3.3. Modelo de dados mínimo (crie nesta ordem)
```elixir
accounts(id, name, locale, settings jsonb)
users(id, email, password_hash, name, role global)
account_users(account_id, user_id, role: admin|agent)
teams(id, account_id, name)
inboxes(id, account_id, name, channel_type: :whatsapp|:telegram, provider_config jsonb, greeting_message)
contacts(id, account_id, name, phone_number, email, additional_attributes jsonb)
contact_inboxes(id, contact_id, inbox_id, source_id) # source_id = wa_id ou telegram chat_id, unique por inbox
conversations(id, account_id, inbox_id, contact_inbox_id, status: open|pending|resolved|snoozed, assignee_id, team_id, last_activity_at)
messages(id, conversation_id, account_id, inbox_id, message_type: incoming|outgoing|activity|template, content, content_type: text|image|audio|video|file|location, status: sent|delivered|read|failed, source_id, sender_id, private bool)
attachments(id, message_id, file_type, external_url, metadata jsonb)
```

Índices críticos: `contact_inboxes(inbox_id, source_id) unique`, `conversations(account_id, status, updated_at)`, `messages(conversation_id, id)`.

### 3.4. Ports & Adapters para canais (Clean Architecture em Elixir)
```elixir
# Behaviour = Port
defmodule Chatwooter.Channels.Channel do
  @callback send_message(inbox :: map(), message :: map()) :: {:ok, %{external_id: String.t()}} | {:error, term()}
  @callback parse_webhook(params :: map()) :: {:ok, [incoming_msg()]} | {:error, term()}
  @callback validate_webhook(conn :: Plug.Conn.t(), inbox :: map()) :: :ok | {:error, term()}
end

# Adapters
Chatwooter.Channels.WhatsApp.CloudApi  # Tesla client Meta
Chatwooter.Channels.Telegram.BotApi    # Tesla client Telegram

# Factory
Chatwooter.Channels.for(:whatsapp) # -> CloudApi
```

Nunca espalhe `HTTPoison.post("graph.facebook.com...")` nos contexts. Todo HTTP externo atrás do Behaviour + `Mox` nos testes.

---

## 4. TDD + Clean Code (como operar todo dia)

### 4.1. Workflow TDD por história (obrigatório)
1. **Red:** `mix test test/chatwooter/conversations_test.exs` falhando, usando factories, sem tocar em `lib/`.
2. **Green:** implementação mínima no context.
3. **Refactor:** extrair, renomear, `mix format`, `mix credo --strict`.
4. Pipeline bloqueia PR se `mix test + credo + dialyzer + format --check` falhar.

### 4.2. Pirâmide de testes
- **70% unitários de context** (ExUnit + Ecto Sandbox, rápidos): `Accounts.create_account/1`, `Conversations.send_message/2`, `WhatsApp.parse_webhook/1`.
- **20% integração** (Oban inline + Bypass para mockar Meta/Telegram): webhook ponta-a-ponta cria conversa + mensagem + broadcast.
- **10% browser** (Wallaby, só 5 fluxos): login → receber WhatsApp → responder → resolver → CSAT.

Exemplo de teste-guia:
```elixir
test "webhook WhatsApp cria conversa e mensagem incoming" do
  inbox = insert!(:inbox, channel_type: :whatsapp)
  payload = Fixtures.whatsapp_text(from: "5511999990001", body: "Olá")

  assert {:ok, [%{conversation_id: cid}]} = WhatsAppIngest.call(inbox, payload)
  assert [%{content: "Olá", message_type: :incoming}] = Conversations.list_messages(cid)
end
```

### 4.3. Convenções Clean Code (colar no AGENTS.md)
- Contexts retornam `{:ok, _} | {:error, Ecto.Changeset.t()}` — nunca levantam exceção em fluxo normal.
- Schemas só têm `changeset/2`. Regra de negócio vai no context.
- Funções ≤ 15 linhas, 1 nível de `with`, nomes do domínio (`resolve_conversation`, não `update_status_2`).
- `provider_config` criptografado com `Cloak` (tokens Meta/Telegram nunca em plain text).
- Todos os efeitos colaterais (enviar WhatsApp, webhook saída) via **Oban**, nunca inline no request.
- Logs estruturados com `account_id`, `inbox_id`, `conversation_id`, `external_id`.

---

## 5. UI Parecida com Chatwoot (LiveView)

Replique o layout em 3 colunas — não invente UX no MVP:

```
+--------+--------------+---------------------------+--------------+
| sidebar| lista convers| thread da conversa        | painel contato|
| (inbox,| (search,     | (bolhas, anexos, privado, | (atributos,  |
|  times,|  filtros,    |  canned, emoji, áudio)    |  notas, labels)|
| config)|  sort)       | + composer embaixo        |              |
+--------+--------------+---------------------------+--------------+
```

Mapeamento LiveView:
- `AppSidebarLive` — troca de inbox, contadores (PubSub `inbox:<id>`).
- `ConversationListLive` — stream de conversas (`phx.stream`), filtros por status/assignee, busca.
- `ConversationThreadLive` — stream de mensagens, optimistic UI, receipts, `phx-hook` p/ scroll + áudio.
- `ContactPanelLive` — edição inline, notas, labels.
- `SettingsLive` — inboxes WhatsApp/Telegram (conectar, webhook URL, testar envio), times, agentes, canned, webhooks.

Design tokens: copie do Chatwoot — fundo `#F8FAFC`, sidebar escura `#1F2937`, azul primário `#1F93FF`, bolha agente `#E9EFF5`, bolha contato branca, fonte Inter. Use Tailwind + componentes `CoreComponents` + `daisyUI` só se precisar.

Composer MVP: texto + emoji + anexo + canned (`/`), nota privada (toggle amarelo), áudio gravado (MediaRecorder → upload). Todo resto (macros, botões interativos WhatsApp) vai pra v1.1.

Tempo real: ao persistir mensagem, `Phoenix.PubSub.broadcast(Chatwooter.PubSub, "conversation:#{id}", {:new_message, msg})`. LiveViews fazem `handle_info` + push. Presence para "digitando..." e "online".

---

## 6. WhatsApp a Fundo (foco 1)

**Decisão:** MVP usa **WhatsApp Cloud API oficial** (não Baileys/QR). Motivo: estabilidade, templates aprovados, receipts. Deixe um adapter `WhatsApp.QrProvider` (Evolution API) como segunda implementação do mesmo Behaviour pós-MVP.

### 6.1. Setup por inbox
Campos `provider_config`: `%{phone_number_id, waba_id, access_token_encrypted, webhook_verify_token}`.
Tela de conexão: passo-a-passo (criar app Meta → token → cadastrar webhook `GET /webhooks/whatsapp/:inbox_id` → testar envio).

### 6.2. Webhook entrada `POST /webhooks/whatsapp/:inbox_id`
1. Verifica `X-Hub-Signature-256` (HMAC com app secret).
2. `WhatsAppIngest` worker (Oban): `parse_webhook` → normaliza para `%{from_wa_id, type, text/media_id, timestamp, reply_to}`.
3. Baixa mídia via Graph API → upload S3/local → cria `Attachment`.
4. `find_or_create Contact + ContactInbox(source_id=wa_id)` → `find_or_create Conversation aberta` → cria `Message incoming`.
5. Broadcast PubSub + dispara webhook de saída + automação.
6. Retorna `200` em <500ms (processa async — Meta re-tenta se demorar).

Tipos suportados MVP: `text`, `image`, `audio`, `video`, `document`, `sticker`(como image), `reaction`(ignora mas loga), `contacts/location`(salva como conteúdo especial). Erros: `unsupported` vira mensagem `activity` "tipo não suportado".

### 6.3. Envio `POST /api/v1/conversations/:id/messages`
Fluxo: `Conversations.send_message` cria `Message outgoing status=sent` → Oban `WhatsAppSender` → `POST https://graph.facebook.com/v21.0/{phone_number_id}/messages` → atualiza `source_id (wamid)` → receipts via webhook (`sent→delivered→read`) atualizam `status`.
Regra 24h: se última incoming >24h, exige **template** (`template_name + params`). UI avisa e oferece seletor de templates.

### 6.4. Testes WhatsApp (TDD)
- `parse_webhook` com fixtures reais (texto, imagem, áudio, template status, erro).
- Bypass mockando Graph API: envio retorna `wamid`, falha 400 vira `status=failed` + retry Oban com backoff.
- Idempotência: mesmo `wamid` entregue 2x cria 1 mensagem (constraint `messages(source_id, inbox_id)` unique).

---

## 7. Telegram a Fundo (foco 2)

**Decisão:** **Bot API via Webhook** (não polling em prod). Um bot = uma inbox.

### 7.1. Setup por inbox
`provider_config`: `%{bot_token_encrypted, bot_username, webhook_secret}`. Ao salvar, chama `setWebhook(https://seu-dominio/webhooks/telegram/:inbox_id?secret=...)`. Botão "Testar" envia mensagem para o admin.

### 7.2. Webhook entrada
Valida `X-Telegram-Bot-Api-Secret-Token`. Normaliza `message`, `edited_message`, `callback_query`, `channel_post`. Mapeia `chat.id → ContactInbox.source_id`, `from.username → Contact.name`. Suporta texto, foto (pega maior `file_id`), voz/áudio, documento, sticker, localização. Baixa via `getFile` → `https://api.telegram.org/file/bot<token>/...` → storage.

### 7.3. Envio
`POST https://api.telegram.org/bot<token>/sendMessage|sendPhoto|sendDocument|sendVoice`. Suporta `reply_to`, Markdown, botões inline (v1.1). Sem regra 24h — vantagem para reengajamento.

### 7.4. Testes Telegram
Fixtures de `update` real, teste de secret inválido → 401, teste de `callback_query` → cria activity na conversa.

---

## 8. Realtime, Jobs, Storage, API

- **PubSub tópicos:** `account:<id>`, `inbox:<id>`, `conversation:<id>`, `user:<id>` (notificações).
- **Oban filas:** `webhook_ingest` (alta prioridade), `senders` (mídia), `outgoing_webhooks`, `notifications`, `maintenance` (snooze, auto-resolve).
- **Storage anexos:** `Waffle`/`ExAws.S3` com disco local em dev. Limite 25MB, virus-scan pós-MVP.
- **API REST v1 (compat Chatwoot):** `GET /api/v1/conversations`, `POST /api/v1/conversations/:id/messages`, `PATCH /api/v1/conversations/:id`, `POST /api/v1/contacts`, webhooks saída assinados HMAC. Gere OpenAPI com `OpenApiSpex`.
- **Auth API:** `Authorization: Bearer <token>` por `access_tokens`.

---

## 9. Roteiro por Fases (com DoD)

### Fase 0 — Fundação (semana 1-2)
- [ ] `mix phx.new`, CI (GitHub Actions: test+credo+dialyzer+sobelow), Docker, `.tool-versions`, Gettext pt-BR.
- [ ] `Accounts` + `phx.gen.auth` + papéis + `Boundaries` + `mix format/credo`.
- [ ] Factories (ExMachina), `DataCase`, arquitetura test.
- **DoD:** login funciona, CI verde, `mix test` <30s.

### Fase 1 — Núcleo de conversas (semana 3-5) [TDD]
- [ ] `Inboxes`, `Contacts`, `Conversations` (CRUD + changesets + testes).
- [ ] LiveView 3 colunas estática + lista/thread com seeds.
- [ ] PubSub + Presence + composer texto.
- **DoD:** 2 agentes conversam entre si em tempo real, coverage >85% nos contexts.

### Fase 2 — Telegram fim-a-fim (semana 6-7)
- [ ] Adapter BotApi + `setWebhook` + ingest worker + envio + anexos.
- [ ] Tela settings Telegram + fixtures + Bypass tests.
- **DoD:** celular → Telegram → inbox → resposta do agente chega no Telegram <3s.

### Fase 3 — WhatsApp fim-a-fim (semana 8-10)
- [ ] Adapter CloudApi + verify webhook + ingest + mídia + receipts + templates + regra 24h.
- [ ] Tela settings WhatsApp + testes idempotência.
- **DoD:** mesmo DoD do Telegram + template fora da janela funciona + receipts atualizam na UI.

### Fase 4 — Produtividade mínima (semana 11-12)
- [ ] Atribuição (auto + manual), times, labels, canned, notas privadas, filtros/busca, snooze, CSAT.
- [ ] Notificações sino + webhooks saída + API v1 básica.
- **DoD:** fluxo de suporte completo sem SQL manual.

### Fase 5 — Hardening v1.0 (semana 13-14)
- [ ] Rate-limit, audit log, backups, Sentry, PromEx, paginação, E2E Wallaby (5 fluxos), i18n completo, docs + onboarding.
- **DoD:** deploy Fly/Hetzner, p95 webhook <400ms, 0 credo issues, release notes.

Estimativa: **1 dev sênior Elixir ≈ 14 semanas p/ v1.0**. Com 2 devs, ~8-9 semanas.

---

## 10. Backlog Priorizado (comece de cima)

```
P0: auth + accounts, inbox CRUD, contact CRUD, conversation CRUD, message send/receive interno, LiveView 3 colunas
P0: telegram ingest+send, whatsapp ingest+send+receipts
P1: anexos, presença/digitação, atribuição, filtros, busca, labels, canned, notas
P1: templates WA, regra 24h, webhooks saída, API v1
P2: snooze, CSAT, macros simples, automation (abertura→atribui time), dashboard contadores
PÓS-V1: email, instagram, campanha, portal, relatórios, AgentBot/LLM, Evolution/QR provider, multi-idioma avançado
```

---

## 11. Riscos e Decisões Travadas

1. **Meta muda API/to kens expiram** → worker `refresh_token` + alerta; versione client (`/v21.0`) e isole em um módulo.
2. **Webhook Meta re-tenta** → idempotência por `source_id` + Oban `unique`.
3. **Mídia grande** → download async, limite tamanho, fallback link.
4. **LiveView vs SPA** → LiveView no MVP; se precisar app mobile, a API v1 já está pronta.
5. **Multitenancy** → `account_id` em toda query via `Ecto.Query` + `Ban` policy; considere `prefix` Postgres só se escalar muito.

---

## 12. Primeiros 5 commits (faça amanhã)

```bash
1. mix phx.new chatwooter --live + CI verde
2. test: Accounts.create_account (RED) → impl (GREEN) → format
3. feat: Inboxes + Contacts + ContactInbox
4. feat: Conversations + Messages + PubSub broadcast
5. feat: LiveView layout 3 colunas com seeds (10 conversas fake)
# depois: telegram adapter + webhook, só então whatsapp
```

Quer que eu gere o `mix phx.new` + esqueleto dos contexts + testes iniciais?
