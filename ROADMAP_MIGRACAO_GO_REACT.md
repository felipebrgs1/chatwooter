# Roadmap — migração Elixir/Phoenix → Go + React

> Decisão de 2026-09-30: trocar a stack para **Go (backend) + React (frontend)**. Motivo principal:
> **adoção**. O público que lê, contribui e mantém Go/React é muito maior que o de Elixir.
> O produto não muda. [`ROTEIRO.md`](./ROTEIRO.md) (decisões de produto),
> [`ROADMAP_PARIDADE_BANCO.md`](./ROADMAP_PARIDADE_BANCO.md) e
> [`ROADMAP_PARIDADE_PRODUTO.md`](./ROADMAP_PARIDADE_PRODUTO.md) continuam valendo. Este documento
> cobre só a troca de stack e a ordem para chegar ao ponto em que o app Elixir estava.
>
> **Atualização (2026-09-30):** o Elixir foi removido do repositório antes do fim da Fase 3 (Fase 6
> antecipada). O código dele está na tag `elixir-final`: os itens ⬜ da Fase 3 são portados a partir dela.

## Regras

- **O app Elixir não existe mais na árvore** (tag `elixir-final`); serve só de consulta para o port.
- Mesmo repositório: backend em `server/`, frontend em `web/`.
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
  cmd/schemadiff/            # compara o banco ao schema.rb (substituiu o mix chatwooter.schema_diff)
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
- **views** leem os tipos dos models, mas não importam banco, controllers nem router.
- Dentro de `models/` a direção antiga continua:
  `channels → conversations → contacts → inboxes → accounts`; o que cruza vira orquestração em
  `models/platform` (`RecordDeletion`, `ContactMerge`).

---

## Fase 0 — Decisão e congelamento

- [x] Tag `elixir-final` no último commit Elixir
- [x] Este roadmap aprovado; nota no topo do `ROTEIRO.md` apontando para cá
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
      `encrypt-provider-configs` (idempotente). Com o Elixir removido, pode rodar no banco de dev (linhas antigas em claro continuam legíveis até lá)

**Frontend**
- [x] `web/` com Vite + React + TS + TanStack Router + Tailwind v4 (Query entra com a primeira chamada de API)
- [x] `tokens.css` e Tailwind v4 trazidos do app atual
- [x] Fonte Inter (`web/public/fonts/Inter`)
- [x] i18next com **en e pt_BR** (demais idiomas fora do escopo): JSON do Chatwoot copiados por `make i18n-sync`;
      sintaxe do vue-i18n (`{var}`, `{'literal'}`, `a | b`) tratada em `src/i18n/index.ts`
- [x] Teste que garante rota = arquivo (`src/routes/routes.test.ts`)

**Infra e processo**
- [x] `docker-compose.yml`: `server` (migrate + seed + air, :4100) e `web-ui` (vite, :5173, proxy para `/api`, `/auth`, `/cable`). `docker compose up`
- [x] `Makefile` com `make precommit` e `make test`
- [x] `make sqlc`, `make migrate`, `make schema-diff`, `make i18n-sync`
- [ ] CI rodando `make precommit`
- [x] `AGENTS.md`: seção Go + React (convenções e comandos)

**DoD:** `docker compose up` sobe tudo, `make precommit` verde, o gate de paridade do schema passa
contra o banco atual.

## Fase 2 — Autenticação e casca do app

- [x] Login com e-mail/senha validando o bcrypt do Devise (`POST /auth/sign_in`, resposta `{data: perfil}`). E-mail ambíguo, senha vazia
      do Devise e usuário inexistente não autenticam (e custam o mesmo tempo). Testado com o usuário real do banco Elixir (`$2b$12$`)
- [x] Sessão por cookie `HttpOnly; SameSite=Lax` (só o SHA-256 do token vai ao banco; tabela `chatwooter_sessions`, 30 dias, purge de hora em hora),
      `DELETE /auth/sign_out`, `GET /api/v1/profile`; escritas com cookie exigem `Origin` do próprio site
- [x] `PUT /api/v1/profile` (nome, display_name, assinatura, `ui_settings` — a largura da sidebar vai em `sidebar_width`),
      `POST /profile/availability`, `POST /profile/auto_offline` e `PUT /profile/set_active_account`, ligados à sidebar (troca de conta, disponibilidade)
- [x] Middleware de escopo `/api/v1/accounts/{account_id}/...`: 404 conta inexistente, 401 quem não é membro (como o Chatwoot).
      Primeira rota escopada: `GET /api/v1/accounts/{id}`
- [ ] Guard de papel (`administrator`) por rota e `account_id` obrigatório nas queries dos models (entra com a primeira rota de dados)
- [x] Access token (`api_access_token`) para a API externa
- [x] Tela de login 1:1 (`chatwoot/app/javascript/v3/views/login/`), sem Google/SAML/MFA (fora do v1); "esqueceu a senha" só visual.
      Guard das rotas `/app/*` com redirect seguro, toast (`useAlert`) portado
- [x] Layout + sidebar (expandida, recolhida, mobile com flyout, menu do perfil, sair) — `AppShell` + `components/sidebar/`.
      Largura e seções minimizadas ficam no `localStorage` até existir `PUT /api/v1/profile` (no Chatwoot vão em `ui_settings`)
- [x] Componentes base `next/*` portados em `web/src/components/next/` (avatar, breadcrumb, button, channel-icon, checkbox,
      combobox, dialog, dropdown-container, dropdown-menu, input, searchable-list, switch, tab-bar + icon), com testes

**DoD:** um usuário vindo de um dump do Chatwoot faz login e vê a casca do app idêntica à atual.

## Fase 3 — Portar o que já existe em Elixir

Cada item recebe testes novos em Go/React **escritos a partir dos testes Elixir** (na tag `elixir-final`; eles são a
especificação). Os itens 🟡 do app atual (estilo antigo) são refeitos direto no padrão 1:1, sem
portar o visual antigo.

**Conversas** (`GET /api/v1/accounts/:id/conversations`, `/meta`, `/filter`, `/search`)
- [x] Lista: abas Mine/Unassigned/All com contadores, status, ordenação, card, scroll infinito (25/página) — `GET /conversations`, `/conversations/meta`
- [x] Layout expandido (preferência em `ui_settings`: `conversation_display_type` + `previously_used_…`); linhas de
      `ConversationCardExpanded` a partir do `lg`, conversa aberta ocupa a área com "Back". Checkbox de seleção entra com as ações em massa
- [x] Filtros da API para Mentions, Participating, Unattended, Team, Label, Inbox (search params de `/app`)
- [x] `GET /labels` e `GET /teams` (index); sidebar com Mentions/Participating/Unattended, Teams (só os do usuário) e Labels (`show_on_sidebar`, com cor)
- [x] `GET /inboxes` (index, escopo do `InboxPolicy`, sem segredos do canal); Channels na sidebar, nome da inbox no card,
      no título da lista (inbox/time) e no cabeçalho da conversa
- [ ] Folders na sidebar (depende de `/custom_filters`); ordenação por seção e contadores de não lidas
- [ ] Filtros avançados, pastas (`custom_filters`) salvar/editar/excluir
- [ ] Menu de contexto do card (lido/não lido, status, prioridade, etiquetas, agente, time, copiar link, excluir)
- [ ] Ações em massa (etiquetas, status, agente, time)
- [x] Etiquetas no card (cor e descrição vindas de `/labels`)
- [x] Conversa aberta: cabeçalho (Resolve/Reopen, `#id` copiável), thread (texto, imagem, vídeo, áudio, arquivo, nota privada, atividade, falha, status de entrega), composer Reply/Private note com envio otimista e reenvio — `GET/POST /conversations/{id}/messages`, `toggle_status`, `assignments`, `update_last_seen`, `unread`
- [ ] Painel do contato, editor rich text, canned, anexos, menções (Marcos 1.2–1.5)

**Contatos e empresas**
- [x] Lista de contatos (`/app/contacts`): cards, busca com "Load more", ordenação em `ui_settings`, paginação —
      `GET /contacts`, `/contacts/search`
- [x] Detalhe do contato (`/app/contacts/:id`): formulário 1:1, bloquear, etiquetas, excluir (admin, cascata síncrona),
      abas History e Notes — `GET/PUT/DELETE /contacts/:id`, `/conversations`, `/labels`, `/notes`
- [ ] Detalhe: "Send message" (nova conversa), abas Attributes (custom attributes), Media e Merge, avatar
- [ ] Criar contato, edição rápida no card, filtros/segmentos, visão por etiqueta, import/export
- [ ] Empresas (lista e detalhe)

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

- [x] Rodar Go + React no lugar do Phoenix em dev
- [ ] Idem em staging com o mesmo banco
- [ ] Ensaio com dump anonimizado do Chatwoot (Marco 6 do roadmap do banco), agora com o Go
- [ ] Marcar no `ROADMAP_PARIDADE_PRODUTO.md` os itens reimplementados

## Fase 6 — Remover o Elixir ✅ (antecipada, 2026-09-30)

- [x] Apagar `lib/`, `test/`, `mix.exs`, `mix.lock`, `config/`, `priv/`, `assets/`, `Dockerfile`, `Dockerfile.dev`,
      `docker/`, `.formatter.exs`, `.dockerignore` e o serviço `web` (Phoenix) do compose
- [x] Reaproveitado: `tokens.css` já estava em `web/src/styles`; `docs/schema_parity_*.json` ficam em `docs/`
      (lidos pelo `cmd/schemadiff`); o seed de dev virou o comando `seed` do Go
- [x] `ROTEIRO_ELIXIR.md` → `ROTEIRO.md`, com a seção de stack atualizada; README e `AGENTS.md` reescritos
- [x] `ROADMAP_PARIDADE_PRODUTO.md` e `ROADMAP_PARIDADE_BANCO.md`: referências a `mix`, LiveView, Oban e Ecto
      trocadas; status de produto remedido na stack Go (o que só existia no Elixir voltou para ⬜)

Perdido até ser portado (Fase 3): Telegram (webhook, ingest, envio), contatos, empresas, busca, settings,
filtros avançados/pastas, menu de contexto, ações em massa, nova conversa, importação de agentes e o setup do
bucket de storage. Também não há imagem de produção: o `Dockerfile` era do release Elixir.

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

1. **Regredir no que já funciona.** Mitigação: os testes Elixir (tag `elixir-final`) são a especificação
   da Fase 3; para comparar lado a lado, suba a tag num checkout separado.
2. **Formato de JSON divergente do Chatwoot.** Mitigação: testes de contrato contra os jbuilder
   desde a Fase 2, não só no Marco 6.
3. **Tempo real mais trabalhoso que no Phoenix.** Mitigação: escopo fechado aos eventos do
   `actionCable.js`; LISTEN/NOTIFY antes de pensar em Redis.
4. **Duas bases de código (Go + TS) e contrato entre elas.** Mitigação: tipos TS gerados do OpenAPI;
   nada escrito à mão dos dois lados.
5. **Paralisia de produto durante a migração.** Mitigação: nenhuma feature nova até a Fase 3 fechar.
   A Fase 3 é o gargalo e deve andar antes de tudo.
