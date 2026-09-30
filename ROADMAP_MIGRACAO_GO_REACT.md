# Roadmap — migração Elixir/Phoenix → Go + React

> Decisão de 2026-09-30: trocar a stack para **Go (backend) + React (frontend)**. Motivo principal:
> **adoção**. O público que lê, contribui e mantém Go/React é muito maior que o de Elixir.
> O produto não muda. [`ROTEIRO_ELIXIR.md`](./ROTEIRO_ELIXIR.md) (decisões de produto),
> [`ROADMAP_PARIDADE_BANCO.md`](./ROADMAP_PARIDADE_BANCO.md) e
> [`ROADMAP_PARIDADE_PRODUTO.md`](./ROADMAP_PARIDADE_PRODUTO.md) continuam valendo. Este documento
> cobre só a troca de stack e a ordem para chegar ao ponto em que o app Elixir está hoje.

## Regras

- **O app Elixir congela.** Só correção de bug até a Fase 5. Nenhum item novo do roadmap de produto
  é feito em Elixir.
- Mesmo repositório: backend em `server/`, frontend em `web/`. O app Elixir continua na raiz até ser
  removido (Fase 6).
- **O banco não muda.** O schema 1:1 com o Chatwoot (103/103 tabelas) é o maior ativo do projeto e
  passa para o Go do jeito que está.
- TDD continua obrigatório (Red → Green → Refactor → `make precommit` verde).
- `chatwoot/` continua como referência read-only. O `.vue` é a fonte da verdade da UI.
- Status: ✅ feito · 🟡 em andamento · ⬜ não iniciado.

---

## Decisões de arquitetura

### 1. O frontend consome a API do próprio Chatwoot

O React fala com o backend pelos **mesmos endpoints e JSON do dashboard do Chatwoot**
(`/api/v1/accounts/:account_id/...`, `/api/v1/profile`, ...), portados de
`chatwoot/config/routes.rb` + `app/views/api/v1/**/*.json.jbuilder`.

Por quê:
- O Marco 6 (compat de API v1) vira efeito colateral: o que o nosso frontend usa já é a API
  compatível.
- Os componentes Vue do Chatwoot já esperam esse formato, então portar para React fica quase mecânico
  (mesmos campos e mesmas stores → mesmas queries).
- Os testes de contrato usam as fixtures do próprio Chatwoot.

Autenticação: o dashboard usa sessão por cookie HttpOnly. A API externa usa o header
`api_access_token` (tabela `access_tokens`), como no Chatwoot.

### 2. Tempo real no formato do ActionCable

Um websocket em `/cable` publica os **mesmos nomes de evento e payloads** de
`chatwoot/app/javascript/dashboard/helper/actionCable.js` (`message.created`,
`conversation.status_changed`, `presence.update`, ...). A distribuição entre instâncias usa Postgres
`LISTEN/NOTIFY`, então não precisamos de Redis no v1.

### 3. Stack

| Camada | Escolha | Substitui |
|---|---|---|
| Linguagem | Go 1.25+ | Elixir |
| HTTP | `net/http` + `chi`, padrão **MVC** | Phoenix Router/Controller |
| Banco | Postgres 18 (mesmo container) + `pgx/v5` | Ecto/Repo |
| Queries | `sqlc` (SQL explícito → código tipado) | Ecto.Query |
| Migrations | `goose` (baseline = schema atual) | `mix ecto.migrate` |
| Jobs | **River** (fila em Postgres) | Oban |
| Websocket | `coder/websocket` + LISTEN/NOTIFY | Phoenix Channels/PubSub/Presence |
| HTTP externo | `net/http` atrás da interface `channels.Channel` | Req + Behaviour |
| Storage | `aws-sdk-go-v2/s3` → RustFS | módulo `Storage` |
| Senha | `golang.org/x/crypto/bcrypt` (lê o `encrypted_password` do Devise) | bcrypt_elixir |
| Segredos | AES-256-GCM em `provider_config` | hoje só `redact` — **não estava criptografado** |
| Contrato | OpenAPI gerado a partir dos handlers → tipos TS | — |
| Frontend | React 19 + Vite + TypeScript | LiveView/HEEx |
| Rotas FE | TanStack Router (file-based) | router + `live/` |
| Dados FE | TanStack Query + cliente WS próprio | assigns/streams |
| CSS | Tailwind v4 + `tokens.css` atual | idem |
| Ícones | `@phosphor-icons/react` | `deps/phosphor` |
| i18n | `i18next` carregando **os JSON de `chatwoot/.../i18n/locale/en`** | textos copiados à mão |
| Editor | ProseMirror + `@chatwoot/prosemirror-schema` (o mesmo do Chatwoot) | a definir |
| Testes BE | `testing` + Postgres real em transação + `httptest` | ExUnit/Sandbox/Bypass/Mox |
| Testes FE | Vitest + Testing Library + MSW; Playwright nos fluxos críticos | LiveViewTest |
| Qualidade | `make precommit`: gofmt, golangci-lint, go test, tsc, oxlint, vitest | `mix precommit` |
| Dev | docker compose: `db`, `rustfs`, `server` (air), `web` (vite) | `web` Phoenix |

### 4. Estrutura (MVC)

```
server/
  cmd/chatwooter/            # main: http + workers
  cmd/schemadiff/            # porta do mix chatwooter.schema_diff
  internal/
    router/                  # URLs -> controllers (toda rota declarada aqui)
    controllers/             # HTTP: lê request, chama models, escolhe a view
    models/                  # regras de negócio + acesso ao banco (accounts, inboxes, contacts,
                             #   conversations, channels/{telegram,whatsapp}, realtime, jobs)
    views/                   # JSON das respostas (espelham os jbuilder do Chatwoot)
    db/                      # pool, migrations goose, queries sqlc (usadas só por models)
    config/ testdb/
web/
  src/
    routes/                  # rota = arquivo (TanStack Router), espelha /app/...
    components/next/         # base genérica (components-next do Chatwoot)
    components/<área>/       # sidebar/, conversation/, contacts/...
    api/                     # clientes gerados + hooks de query
    i18n/                    # aponta para os JSON en do Chatwoot
```

Fluxo de uma request: `router → controller → model → (banco) → view → JSON`.
Regras, verificadas pelo `depguard` no `make precommit`:
- **controllers** nunca importam `pgx` nem `db`; só chamam models.
- **models** nunca importam `net/http`, controllers, views nem router.
- **views** recebem dados prontos: não importam models, controllers nem router.
- Dentro de `models/` a direção antiga continua:
  `channels → conversations → contacts → inboxes → accounts`; o que cruza vira orquestração em
  `models/platform` (`RecordDeletion`, `ContactMerge`).

---

## Fase 0 — Decisão e congelamento

- [ ] Tag `elixir-final` no último commit Elixir
- [ ] Este roadmap aprovado; nota no topo do `ROTEIRO_ELIXIR.md` apontando para cá
- [ ] Levantar tudo que o app Elixir faz hoje e virar checklist da Fase 3 (feito abaixo; conferir)

## Fase 1 — Fundação

**Backend**
- [x] `server/` com `go.mod`, `chi`, config por env, logging estruturado (`slog`), healthcheck
- [x] Baseline `goose`: `pg_dump --schema-only` do schema atual (108 tabelas: 103 upstream + 5 locais), **sem** Oban,
      `schema_migrations` e `users_tokens` (as sessões do Go ganham migration própria na Fase 2)
- [x] Gate de paridade: `internal/schemaparity` (parser do `schema.rb` + comparador do catálogo) e `cmd/schemadiff`.
      O teste `TestMigratedDatabaseMatchesUpstreamSnapshot` exige 103/103 tabelas, 1129 colunas, 334 índices,
      17 FKs, 1 check, 5 extensões e 4 triggers (só presença) idênticos ao snapshot. `make schema-diff` imprime o relatório.
- [x] `sqlc` configurado (`make sqlc`): lê o baseline, `timestamp` → `time.Time`; enums do Rails ficam como inteiros, como no banco
- [x] River (`internal/jobs`) com as 6 filas `webhook_ingest`, `senders`, `outgoing_webhooks`, `notifications`,
      `maintenance`, `import`; migrations do River rodam depois do baseline. O `serve` só inicia a fila quando houver
      workers registrados (o primeiro chega com o Telegram, Fase 3)
- [x] Helper de teste: Postgres real, um banco descartável por teste (`internal/testdb`)
- [x] Factories em Go (`internal/factory`: conta, usuário, inbox Telegram, contato, conversa, mensagem)
- [x] Criptografia de `provider_config` (AES-256-GCM, `ENCRYPTION_KEY`): `models.InboxConfigs` + comando
      `encrypt-provider-configs` (idempotente). **Não rodar no banco compartilhado com o Elixir**: o app Elixir lê o mapa em texto claro

**Frontend**
- [x] `web/` com Vite + React + TS + TanStack Router + Tailwind v4 (Query entra com a primeira chamada de API)
- [x] `tokens.css` e Tailwind v4 trazidos do app atual
- [x] Fonte Inter (`web/public/fonts/Inter`)
- [x] i18next com **en e pt_BR** (demais idiomas fora do escopo): JSON do Chatwoot copiados por `make i18n-sync`;
      sintaxe do vue-i18n (`{var}`, `{'literal'}`, `a | b`) tratada em `src/i18n/index.ts`
- [x] Teste que garante rota = arquivo (`src/routes/routes.test.ts`)

**Infra e processo**
- [x] `docker-compose.yml` (perfil `go`): `server` (air, :4100) e `web-ui` (vite, :5173, proxy para `/api`, `/auth`, `/cable`). `docker compose --profile go up`
- [x] `Makefile` com `make precommit` e `make test`
- [x] `make sqlc`, `make migrate`, `make schema-diff`, `make i18n-sync`
- [ ] CI rodando `make precommit`
- [x] `AGENTS.md`: seção Go + React (convenções e comandos)

**DoD:** `docker compose up` sobe tudo, `make precommit` verde, o gate de paridade do schema passa
contra o banco atual.

## Fase 2 — Autenticação e casca do app

- [ ] Login com e-mail/senha validando o bcrypt do Devise (usuários restaurados entram) — `POST /auth/sign_in`
- [ ] Sessão por cookie, logout, `GET /api/v1/profile`, troca de conta
- [ ] Middleware de escopo: `account_id` em toda query (multitenancy), papel admin/agent
- [ ] Access token (`api_access_token`) para a API externa
- [ ] Tela de login 1:1 (`chatwoot/app/javascript/v3/views/login/`)
- [ ] Layout + sidebar (expandida, recolhida, mobile, perfil + disponibilidade)
- [ ] Componentes base `next/*`: avatar, breadcrumb, button, channel-icon, checkbox, combobox, dialog,
      dropdown-container, dropdown-menu, input, searchable-list, switch, tab-bar

**DoD:** um usuário vindo de um dump do Chatwoot faz login e vê a casca do app idêntica à atual.

## Fase 3 — Portar o que já existe em Elixir

Cada item recebe testes novos em Go/React **escritos a partir dos testes Elixir** (eles são a
especificação). Os itens 🟡 do app atual (estilo antigo) são refeitos direto no padrão 1:1, sem
portar o visual antigo.

**Conversas** (`GET /api/v1/accounts/:id/conversations`, `/meta`, `/filter`, `/search`)
- [ ] Lista: abas, status, ordenação, card, layout expandido (preferência em `ui_settings`)
- [ ] Visões Mentions, Participating, Unattended, por Team, por Label + itens na sidebar
- [ ] Filtros avançados, pastas (`custom_filters`) salvar/editar/excluir
- [ ] Menu de contexto do card (lido/não lido, status, prioridade, etiquetas, agente, time, copiar link, excluir)
- [ ] Ações em massa (etiquetas, status, agente, time)
- [ ] Etiquetas no card
- [ ] Thread, cabeçalho, composer e painel (funcionais; o 1:1 vem nos Marcos 1.2–1.5)

**Contatos e empresas**
- [ ] Detalhe do contato + "Send message" (nova conversa)
- [ ] Lista de contatos, empresas (lista e detalhe) — já no padrão `n-*`
- [ ] Merge e exclusão de contato (`platform.ContactMerge`, `platform.RecordDeletion`)

**Busca e composição**
- [ ] Busca global `/app/search` (conversas, mensagens, contatos, buscas recentes)
- [ ] Nova conversa pela sidebar (`platform.ComposeConversation`)

**Canais**
- [ ] Telegram: webhook `POST /webhooks/telegram/:inbox_id` com secret, ingest assíncrono, mídia no storage, sender com retry
- [ ] Interface `channels.Channel` pronta para receber o WhatsApp

**Settings e dados**
- [ ] Inboxes, agents, profile (direto no 1:1 do Marco 3)
- [ ] `ui_settings` com as chaves do Chatwoot
- [ ] Importação de agentes (`imports`)
- [ ] Storage: comando de setup do bucket (porta de `mix chatwooter.storage.setup`)

**DoD:** o app Go + React faz tudo o que o app Elixir fazia na tag `elixir-final`, com testes.

## Fase 4 — Tempo real

- [ ] Hub `/cable` autenticado por sessão, com canal por conta e por usuário
- [ ] Eventos com os nomes e payloads do `actionCable.js`, publicados via LISTEN/NOTIFY
- [ ] Cliente WS no React atualizando o cache do TanStack Query
- [ ] Presence de agentes (online/busy/offline, auto-offline)
- [ ] `TimeAgo` que se atualiza sozinho

**DoD:** dois navegadores lado a lado veem mensagem nova, mudança de status e atribuição em menos de 1s.

## Fase 5 — Cutover interno

- [ ] Rodar Go + React no lugar do Phoenix em dev e em staging com o mesmo banco
- [ ] Ensaio com dump anonimizado do Chatwoot (Marco 6 do roadmap do banco), agora com o Go
- [ ] Marcar no `ROADMAP_PARIDADE_PRODUTO.md` os itens reimplementados

## Fase 6 — Remover o Elixir

- [ ] Apagar `lib/`, `test/`, `mix.exs`, `mix.lock`, `config/`, `priv/`, `assets/`, `Dockerfile.dev`, `.formatter.exs`, `.credo.exs`
- [ ] Mover o que for reaproveitado (`tokens.css`, `docs/schema_parity_*.json`) para `server/`/`web/` antes
- [ ] `ROTEIRO_ELIXIR.md` → `ROTEIRO.md`, com a seção de stack atualizada
- [ ] `ROADMAP_PARIDADE_PRODUTO.md` e `ROADMAP_PARIDADE_BANCO.md`: trocar referências a
      `mix`, LiveView, Oban e Ecto pelos equivalentes Go/React

**DoD:** o repositório não tem mais Elixir e `make precommit` é o único gate.

---

## Depois da migração

Segue o [`ROADMAP_PARIDADE_PRODUTO.md`](./ROADMAP_PARIDADE_PRODUTO.md) do ponto onde parou
(Marco 1.1 → Marco 7), sem mudar a ordem nem o escopo (só WhatsApp Cloud + Telegram).
Nessa stack, dois itens ficam mais baratos:
- **Marco 1.4 (editor):** usar direto o `@chatwoot/prosemirror-schema`, como o Chatwoot.
- **Marco 6 (API v1):** já sai pronto em grande parte por causa da Decisão 1; falta cobrir os
  endpoints que o dashboard não usa e os webhooks de saída.

## Riscos

1. **Regredir no que já funciona.** Mitigação: os testes Elixir viram a especificação da Fase 3 e o
   app Elixir fica de pé até a Fase 5 para comparação lado a lado.
2. **Formato de JSON divergente do Chatwoot.** Mitigação: testes de contrato contra os jbuilder
   desde a Fase 2, não só no Marco 6.
3. **Tempo real mais trabalhoso que no Phoenix.** Mitigação: escopo fechado aos eventos do
   `actionCable.js`; LISTEN/NOTIFY antes de pensar em Redis.
4. **Duas bases de código (Go + TS) e contrato entre elas.** Mitigação: tipos TS gerados do OpenAPI;
   nada escrito à mão dos dois lados.
5. **Paralisia de produto durante a migração.** Mitigação: nenhuma feature nova até a Fase 3 fechar.
   A Fase 3 é o gargalo e deve andar antes de tudo.
