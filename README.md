# Chatwooter — Chatwoot Refatorado em Elixir + Phoenix

> Reconstrução do [Chatwoot](https://github.com/chatwoot/chatwoot) (referência em `chatwoot/`) como **monolito modular em Elixir + Phoenix LiveView**, com **TDD + Clean Code**, foco inicial em **WhatsApp e Telegram** e **UI equivalente ao Chatwoot**.
>
> Roteiro detalhado: [`ROTEIRO_ELIXIR.md`](./ROTEIRO_ELIXIR.md)

[![Elixir](https://img.shields.io/badge/elixir-1.20-purple)](https://elixir-lang.org)
[![Phoenix](https://img.shields.io/badge/phoenix-1.8-orange)](https://phoenixframework.org)
[![Tailwind](https://img.shields.io/badge/tailwind-4.3-blue)](https://tailwindcss.com)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

---

## 1. Visão

Paridade funcional com o essencial do Chatwoot 4.18, sem carregar o legado Rails + Vue + todos os canais:

- **Escopo v1.0:** multi-conta, agentes/times, inboxes, contatos, conversas, mensagens, anexos, tempo real, canned responses, labels, notas privadas, CSAT, webhooks de saída + API REST v1.
- **Canais v1.0:** apenas `WhatsApp Cloud API (Meta)` e `Telegram Bot API`. Email, Instagram, Facebook, X, SMS e demais ficam para pós-v1 como novos adapters do mesmo `Behaviour`.
- **UI:** réplica do dashboard Chatwoot em 3 colunas (sidebar + lista + thread + painel do contato) feita em **LiveView + Tailwind**, sem SPA separada no MVP.

```
+---------+--------------+---------------------------+--------------+
| sidebar | lista        | thread da conversa        | painel       |
| inboxes | conversas    | bolhas + composer         | contato      |
+---------+--------------+---------------------------+--------------+
```

---

## 2. Stack (mais recente, travada)

| Camada | Versão | Pacote |
|---|---|---|
| Elixir | `1.20.x` (mín. 1.17, OTP 27–29) | ver `.tool-versions` |
| Erlang/OTP | `27+` | — |
| Phoenix | `1.8.15` | `{:phoenix, "~> 1.8.15"}` |
| Phoenix LiveView | `1.2.x` | `{:phoenix_live_view, "~> 1.2.0"}` |
| Tailwind CSS | `4.3.3` | `{:tailwind, "~> 0.5"}` + binário Tailwind v4 |
| UI base | daisyUI v5 + Heroicons v2 | gerenciados via `mix.exs` (github) |
| Banco | Postgres `16+` | `{:ecto_sql, "~> 3.13"}` + `{:postgrex, ">= 0.0.0"}` |
| Jobs | Oban `2.19+` | `{:oban, "~> 2.19"}` (config comentada até Fase 1, ver `config/config.exs`) |
| Realtime | PubSub + Presence (nativo Phoenix) | — |
| Auth | `phx.gen.auth` + Guardian (JWT p/ API) | — |
| HTTP externo | Req + Bypass (testes) | `{:req, "~> 0.5"}` — não usar Tesla/HTTPoison |
| Testes | ExUnit + Mox + ExMachina + Wallaby | — |
| Qualidade | format + Credo + Dialyxir + Sobelow + Boundaries | — |
| Observabilidade | Telemetry + PromEx + Sentry | — |

> **Tailwind 4+:** sem `tailwind.config.js`. Configuração é CSS-first via `@import "tailwindcss"` e `@theme` em `assets/css/app.css`. O wrapper `phoenixframework/tailwind` `0.4+` assume v4 por padrão.

---

## 3. Pré-requisitos

- Elixir `1.20.4` + OTP `28` (via `mise`/`asdf`)
- Node `20+` (só p/ assets), Postgres `16+`, Redis (Oban/Presence em cluster, opcional em dev)
- Conta Meta (WhatsApp Cloud API) e bot Telegram (só a partir da Fase 2/3)

```bash
# via mise (recomendado — pinado em .tool-versions)
mise install          # lê .tool-versions (elixir/erlang/nodejs/postgres)
mix local.hex --force
mix archive.install hex phx_new --force   # só p/ consultar o upstream

elixir --version  # Elixir 1.20.x
```

---

## 4. Quickstart (scaffold Phoenix já commitado neste repo)

### Via Docker (recomendado — sobe app + Postgres)

```bash
docker compose up --build -d   # primeira vez compila deps (~3-5 min)
docker compose logs -f web     # acompanhe até "Running ChatwooterWeb.Endpoint"
# -> http://localhost:4000
# registro: http://localhost:4000/users/register (link mágico em /dev/mailbox)
```

### Local (precisa Erlang/OTP completo + Postgres na 5432)

```bash
mix deps.get
mix ecto.setup        # create + migrate + seeds
mix assets.setup        # tailwind.install + esbuild.install (se necessário)
mix phx.server
# -> http://localhost:4000
```

Comandos do dia a dia:

```bash
mix phx.server          # dev
mix ecto.migrate        # migrações
mix ecto.seed           # seeds (10 conversas fake p/ UI)
mix test                # testes
mix test --cover        # coverage
mix format              # formata
mix credo --strict      # lint
mix dialyzer            # tipos
mix sobelow --config    # segurança
```

Estrutura do repo:

```
.
├── README.md               # este arquivo
├── ROTEIRO_ELIXIR.md       # fases, TDD, WhatsApp/Telegram a fundo
├── AGENTS.md               # convenções Phoenix 1.8 + regras do projeto
├── mix.exs                 # deps (Phoenix 1.8.15, LiveView 1.2, Tailwind 4.3.3, Oban…)
├── .tool-versions          # pins elixir/erlang/nodejs/postgres
├── config/                 # config.exs, dev/test/prod/runtime.exs
├── chatwoot/               # referência read-only do Chatwoot original (Rails+Vue) — não editar
├── lib/
│   ├── chatwooter/         # domínio (hoje: application/repo/mailer — Fase 1 cria os contexts)
│   │   ├── accounts/       # (Fase 1) Account, User, Team
│   │   ├── inboxes/        # (Fase 1) Inbox (whatsapp|telegram)
│   │   ├── contacts/       # (Fase 1) Contact, ContactInbox, Note, Label
│   │   ├── conversations/  # (Fase 1) Conversation, Message, Attachment
│   │   ├── channels/       # (Fase 2-3) Behaviour + adapters whatsapp/telegram
│   │   ├── automations/    # pós-MVP
│   │   ├── notifications/
│   │   └── platform/       # webhooks saída, tokens API
│   └── chatwooter_web/     # endpoint, router, controllers, components, (Fase 1: live/)
├── priv/repo/migrations/   # (Fase 1: accounts→…→attachments; Oban após Fase 1)
├── test/                   # test_helper + support/ (DataCase, ConnCase)
├── assets/css/app.css      # Tailwind v4 CSS-first + tokens Chatwoot (@theme)
└── assets/js/app.js        # LiveSocket + hooks colocados
```

Regra de dependência (monolito modular):

```
Channels -> Conversations -> Contacts -> Inboxes -> Accounts
Workers  -> Channels + Conversations
Web      -> Contexts (nunca Web -> Repo direto)
```

---

## 5. Tailwind CSS 4+ neste projeto

Não existe `tailwind.config.js` / `postcss.config.js`. Tudo é CSS-first (sintaxe gerada pelo `phx_new 1.8` — manter):

```css
/* assets/css/app.css (trecho real) */
@import "tailwindcss" source(none);
@source "../css";
@source "../js";
@source "../../lib/chatwooter_web";
@plugin "../vendor/heroicons";
@plugin "daisyui/packages/bundle/daisyui" { themes: false; }

/* tokens Chatwoot */
@theme {
  --color-primary: #1f93ff;
  --color-sidebar: #1f2937;
  --color-canvas: #f8fafc;
  --color-bubble-agent: #e9eff5;
  --font-sans: "Inter", ui-sans-serif, system-ui, sans-serif;
}
```

> Regra do projeto: **não usar `@apply`** (convenção do Phoenix 1.8). Componentes do dashboard (`.bubble-agent`, `.bubble-contact`, `.composer`) estão em CSS puro no final do `app.css`.

```elixir
# config/config.exs (real — gerado pelo phx_new)
config :tailwind,
  version: "4.3.3",
  chatwooter: [
    args: ~w(--input=assets/css/app.css --output=priv/static/assets/css/app.css),
    cd: Path.expand("..", __DIR__)
  ]
```

```elixir
# mix.exs (real)
{:tailwind, "~> 0.5", runtime: Mix.env() == :dev}
```

```bash
mix tailwind.install        # baixa binário v4
mix tailwind default        # build manual
mix assets.setup && mix assets.build && mix assets.deploy
```

Dark mode, variantes e tokens novos: estenda via `@theme` e `@custom-variant`, nunca editando CSS gerado em `priv/static`.

---

## 6. Arquitetura resumida

Ver detalhes em [`ROTEIRO_ELIXIR.md`](./ROTEIRO_ELIXIR.md#3-arquitetura-monolito-modular-a-parte-mais-importante).

- **Contexts** retornam `{:ok, _} | {:error, changeset}`. Schemas só têm `changeset/2`.
- **Canais** atrás de um `Behaviour`:

```elixir
defmodule Chatwooter.Channels.Channel do
  @callback send_message(inbox :: map(), message :: map()) ::
              {:ok, %{external_id: String.t()}} | {:error, term()}
  @callback parse_webhook(params :: map()) ::
              {:ok, [map()]} | {:error, term()}
end
```

- Todo efeito colateral (envio WhatsApp/Telegram, webhook saída) via **Oban**, nunca inline no request.
- Realtime via `Phoenix.PubSub`: tópicos `account:<id>`, `inbox:<id>`, `conversation:<id>`.
- `inboxes.provider_config` criptografado (Cloak). Tokens Meta/Telegram nunca em plain text.

Modelo mínimo (ordem de criação): `accounts → users → account_users → teams → inboxes → contacts → contact_inboxes(source_id unique/inbox) → conversations → messages(source_id unique) → attachments`.

---

## 7. TDD + Clean Code

Workflow obrigatório por história: **RED → GREEN → REFACTOR** (`mix format` + `credo --strict`). CI bloqueia PR se falhar `test + format --check + credo + dialyzer + sobelow`.

```bash
mix test test/chatwooter/conversations_test.exs
mix test --cover
mix credo --strict
```

Pirâmide: 70% unit de context (ExUnit + Ecto Sandbox) · 20% integração (Oban inline + Bypass mockando Meta/Telegram) · 10% browser (Wallaby, 5 fluxos críticos).

---

## 8. WhatsApp + Telegram (resumo)

**WhatsApp Cloud API (oficial):** webhook `POST /webhooks/whatsapp/:inbox_id` valida `X-Hub-Signature-256`, worker `WhatsAppIngest` normaliza, baixa mídia, faz find-or-create de `Contact/ContactInbox(wa_id)/Conversation`, cria `Message incoming`, broadcast. Envio via `POST https://graph.facebook.com/v21.0/{phone_number_id}/messages`, receipts `sent→delivered→read` via webhook. Fora da janela 24h exige **template**.

**Telegram Bot API:** webhook `POST /webhooks/telegram/:inbox_id` valida `X-Telegram-Bot-Api-Secret-Token`, mapeia `chat.id → source_id`, suporta texto/foto/voz/doc/sticker/location via `getFile`. Envio via `sendMessage|sendPhoto|sendDocument|sendVoice`. Sem regra 24h.

> Faça Telegram antes do WhatsApp — valida o pipeline com menos fricção. Detalhe completo no roteiro (§6–§7).

Variáveis (dev via `config/dev.exs` ou `.env` + `dotenv`):

```bash
DATABASE_URL=postgres://postgres:postgres@localhost:5432/chatwooter_dev
WHATSAPP_VERIFY_TOKEN=...
TELEGRAM_WEBHOOK_SECRET=...
S3_BUCKET=...            # anexos (disco local em dev)
SENTRY_DSN=...
```

---

## 9. API v1 (compat Chatwoot)

```
GET   /api/v1/conversations
POST  /api/v1/conversations/:id/messages
PATCH /api/v1/conversations/:id            # status, assignee, team
POST  /api/v1/contacts
POST  /webhooks/whatsapp/:inbox_id
POST  /webhooks/telegram/:inbox_id
```

Auth API: `Authorization: Bearer <access_token>`. OpenAPI via `OpenApiSpex` (a gerar na Fase 4).

---

## 10. Roadmap

| Fase | Entrega | DoD |
|---|---|---|
| 0 (1–2 sem) | base Phoenix 1.8 + CI + auth | login + CI verde — ✅ base + auth LiveView (`Accounts/User`, 115 testes verdes); CI pendente |
| 1 (3–5) | contexts core + LiveView 3 colunas | 2 agentes conversam realtime, cov >85% |
| 2 (6–7) | Telegram fim-a-fim | celular→inbox→resposta <3s |
| 3 (8–10) | WhatsApp fim-a-fim + templates | receipts na UI + 24h/template ok |
| 4 (11–12) | atribuição, labels, canned, API v1 | fluxo suporte sem SQL |
| 5 (13–14) | hardening + deploy | p95 webhook <400ms, 0 credo issues |

Estimativa: ~14 sem (1 sênior) · ~8–9 sem (2 devs).

---

## 11. Contribuindo

1. Abra branch `feat/<context>-<historia>`.
2. Escreva o teste primeiro (RED), implemente (GREEN), refatore.
3. Rode `mix format && mix test && mix credo --strict` antes do push.
4. PR pequeno (1 context), com teste + migração + screenshot LiveView se mexer em UI.
5. Não edite `chatwoot/` (referência). Não commite token/secret.

---

## 12. Licença

MIT (a definir — o Chatwoot original é MIT; manter compatibilidade). Veja `LICENSE` quando adicionado.
