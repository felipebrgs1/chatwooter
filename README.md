# Chatwooter — Chatwoot reconstruído em Go + React

> Reconstrução do [Chatwoot](https://github.com/chatwoot/chatwoot) (referência read-only em `chatwoot/`) como
> **API Go + dashboard React**, com **TDD**, escopo de canais **WhatsApp Cloud API + Telegram Bot API** e
> **UI e API 1:1 com o Chatwoot** (mesmas rotas, JSON e schema de banco, para migrar contas sem mudar integrações).
>
> Produto planejado: [`ROTEIRO.md`](./ROTEIRO.md). Andamento: [migração Go + React](./ROADMAP_MIGRACAO_GO_REACT.md) ·
> [paridade de produto/UI](./ROADMAP_PARIDADE_PRODUTO.md) · [paridade do banco](./ROADMAP_PARIDADE_BANCO.md) ·
> [estado medido do schema](./docs/SCHEMA_PARITY.md). O plano descreve o produto, não o que já está pronto.
>
> A primeira versão foi feita em Elixir/Phoenix LiveView; o código está na tag `elixir-final`.

---

## Stack

| Camada | Escolha |
|---|---|
| API (`server/`) | Go, `chi`, MVC (`router → controllers → models`, JSON em `views`) |
| Banco | Postgres 18 (pgvector), schema idêntico ao `schema.rb` do Chatwoot; migrations `goose`, queries `sqlc` |
| Jobs | River (todo efeito externo: envio para Meta/Telegram, webhooks de saída) |
| Dashboard (`web/`) | React + TypeScript + Vite, TanStack Router/Query, Tailwind v4, i18n do Chatwoot, ícones Phosphor |
| Testes | `go test` com Postgres real (banco descartável por teste); Vitest + Testing Library + MSW |
| Storage | S3-compatível (RustFS em dev) |

Convenções de código e regras para agentes: [`AGENTS.md`](./AGENTS.md).

---

## Rodando em dev

Pré-requisitos: Docker. Para rodar testes e ferramentas no host: Go (versão em `server/go.mod`) e Bun.

```bash
cp .env.example .env
docker compose up --build
# API:       http://localhost:4100
# Dashboard: http://localhost:5173/app/login
# login:     john@acme.inc / Password123! (admin da conta "Acme Inc")
```

Na subida o `server` aplica as migrations e o seed de desenvolvimento (idempotente) e roda com hot reload (`air`);
o `web-ui` roda o Vite com proxy de `/api`, `/auth` e `/cable` para o server.

Comandos (na raiz):

```bash
make precommit     # gate: formatação, lint, typecheck e todos os testes
make test          # testes Go + web (os do Go usam o Postgres do compose na porta 5434)
make fmt           # formata Go e web
make sqlc          # regenera o código das queries (server/internal/db/queries/*.sql)
make migrate       # aplica as migrations no banco de dev
make seed          # recria o usuário de dev, se faltar
make schema-diff   # compara o banco de dev ao schema.rb do Chatwoot
make i18n-sync     # copia os textos en/pt_BR do Chatwoot para o web
```

Os testes do Go precisam do Postgres: `docker compose up -d db`.

---

## Estrutura

```
.
├── server/                 # API Go
│   ├── cmd/chatwooter      # binário: serve, migrate, seed, encrypt-provider-configs
│   ├── cmd/schemadiff      # diagnóstico de paridade do schema
│   └── internal/
│       ├── router          # rotas da API (caminhos do Chatwoot)
│       ├── controllers     # HTTP
│       ├── models          # regras + dados (único pacote que usa o sqlc)
│       ├── views           # JSON (espelha os .jbuilder do Chatwoot)
│       ├── db              # migrations goose, queries e código sqlc
│       ├── jobs            # workers River
│       ├── schemaparity    # gate: schema igual ao schema.rb
│       ├── factory, testdb # dados e banco de teste
│       └── secrets         # AES-GCM dos tokens de canal
├── web/                    # dashboard React (rota = arquivo em src/routes)
├── docs/                   # estado medido da paridade do schema
└── chatwoot/               # referência read-only do Chatwoot (Rails + Vue) — nunca editar
```

---

## Canais

**Telegram Bot API** e **WhatsApp Cloud API**, atrás da interface `channels.Channel`: webhook validado
(`X-Telegram-Bot-Api-Secret-Token` / `X-Hub-Signature-256`), ingest assíncrono, mídia no storage, envio com
retry pelo River e, no WhatsApp, receipts, templates e a regra de 24h. Ainda não implementados na stack Go
(ver o roadmap); detalhes no [roteiro](./ROTEIRO.md#7-whatsapp-cloud-api-oficial-e-telegram-bot-api-via-webhook).

---

## Contribuindo

1. Branch `feat/<área>-<história>`.
2. Teste primeiro (red), implementação mínima (green), refatoração com a suíte verde.
3. `make precommit` verde antes do push.
4. Tela nova: port 1:1 do `.vue` do Chatwoot, conferida no browser.
5. Não edite `chatwoot/`. Não commite tokens nem segredos.

---

## Licença

MIT (a definir — o Chatwoot original é MIT; manter compatibilidade).
