# Chatwooter — guia para agentes

> **Migração em curso (2026-09-30):** a stack está indo de Elixir/Phoenix para Go + React — ver
> `ROADMAP_MIGRACAO_GO_REACT.md`. O Elixir está congelado (só bug). Código novo vai em `server/` (Go) e
> `web/` (React); `make precommit` é o gate deles. TDD, port 1:1 do `.vue` e regras de tokens/Phosphor
> continuam valendo. Backend Go em **MVC** (`router → controllers → models`, respostas em `views`;
> regras no `server/.golangci.yml`); um único `web/tsconfig.json`. As seções "Phoenix/Elixir" abaixo só se aplicam ao app Elixir.

Reimplementação do Chatwoot em Elixir/Phoenix LiveView. Visão: `ROTEIRO_ELIXIR.md`; o que falta para
ficar 1:1 (checklist, em ordem): `ROADMAP_PARIDADE_PRODUTO.md` — marque os itens ao concluir.
`chatwoot/` é a referência read-only do original (Rails + Vue) — **nunca editar**.
Escopo v1: só WhatsApp Cloud API + Telegram Bot API.

O app roda em Docker (`deps/` e `_build/` em volumes do `chatwooter-web-1`). Rode mix lá dentro:
`docker exec chatwooter-web-1 sh -c 'MIX_ENV=test mix test'`. Mudou `mix.lock`? `mix deps.get` no container e reinicie.

## Go + React (stack nova — `server/` e `web/`)

Comandos (raiz): `make precommit` (gate), `make test`, `make sqlc`, `make migrate`, `make schema-diff`,
`make i18n-sync`. Testes do Go precisam de Postgres: `docker compose up -d db` (porta `5434`, `TEST_DATABASE_URL`
já vem do Makefile). Stack de dev: `docker compose --profile go up` (API `:4100`, web `:5173`).

**Backend (MVC)** — `router → controllers → models`, resposta em `views` (regras impostas pelo `depguard`).
- Controller nunca importa `pgx`/`db`; model nunca importa `net/http`; view só serializa.
- SQL fica em `internal/db/queries/*.sql` e vira código com `sqlc`; só `models` usa o código gerado.
  Não edite `internal/db/sqlc/`. Schema novo = migration `goose` nova em `internal/db/migrations`, nunca editar o baseline.
- O schema tem de continuar idêntico ao `schema.rb` do Chatwoot: `internal/schemaparity` é o gate.
- Dados de teste: `internal/factory`; banco real descartável por teste: `internal/testdb`. Sem mocks de banco.
- Segredos (tokens de canal) só via `models.InboxConfigs` (AES-GCM); nunca logar nem guardar em claro.
- Jobs com efeito externo só pelo River (`internal/jobs`); worker novo entra em `jobs.Workers()`.
- Teste primeiro; `*_test.go` ao lado do código, pacote `_test`.

**Frontend**
- Rota = arquivo em `src/routes` (TanStack Router); `routeTree.gen.ts` é gerado, não edite.
- Textos vêm do i18n (`t('CHAVE.DO.CHATWOOT')`), só `en` e `pt_BR`; nunca string fixa na tela.
  Sintaxe vue-i18n (`{var}`, `a | b`) já é tratada. Atualizou a referência? `make i18n-sync`.
- Um `tsconfig.json` só. Cores só por tokens (`src/styles/tokens.css`), ícones só Phosphor.
- Teste com Testing Library; ache elementos por papel/texto, não por implementação.

## TDD (obrigatório)

1. **Red** — teste do comportamento; rode e veja falhar pelo motivo certo.
2. **Green** — o mínimo de código para passar.
3. **Refactor** — com a suíte verde.
4. **`mix precommit`** verde (warnings-as-errors, format, credo, testes) antes de dar como pronto.

- Bug: primeiro o teste que o reproduz. Refatoração pura não altera testes.
- Contexts → `test/chatwooter/*_test.exs` (`DataCase`). Telas e componentes → `test/chatwooter_web/live/*_test.exs`
  (`ConnCase` + `LiveViewTest`). Ferramentas: ExMachina (`Chatwooter.Factory`), Mox, Bypass.
- Testes de UI usam ids estáveis e `has_element?/2`; testam o resultado, não a implementação.
- Tela nova ou alterada: confira também no browser.

## Backend

- Contexts em `lib/chatwooter/`. Dependência numa direção só: `Channels -> Conversations -> Contacts -> Inboxes -> Accounts`.
  O que cruza contra ela vira orquestração em `Chatwooter.Platform.*` (ex.: `RecordDeletion`, `ContactMerge`).
- `ChatwooterWeb` nunca usa `Repo`, só contexts.
- HTTP com Meta/Telegram: `Req` atrás do Behaviour `Chatwooter.Channels.Channel`; tokens em `provider_config`
  criptografado; efeitos colaterais só via Oban.
- Preferências de UI em `users.ui_settings` (chaves do Chatwoot) via `Accounts.update_ui_settings/2`.

## Frontend

```
lib/chatwooter_web/
  components.ex            # registro de todos os componentes (registre os novos aqui)
  components/next/         # base genérica do Chatwoot (button, input, combobox, dialog...)
  components/<área>/       # sidebar/, conversation/, contacts/...
  live/                    # páginas: a pasta espelha a URL (ver abaixo)
```

**Rota = arquivo** (conferido por `test/chatwooter_web/live_routes_test.exs`). Cada página tem `.ex`
(estado + eventos) e `.html.heex` ao lado (sem `render/1` inline):

| URL | arquivo | módulo |
|---|---|---|
| `/app` | `live/conversations/index.ex` | `ConversationsLive.Index` |
| `/app/contacts` | `live/contacts/index.ex` | `ContactsLive.Index` |
| `/app/contacts/:id` | `live/contacts/show.ex` | `ContactsLive.Show` |
| `/app/settings/inboxes` | `live/settings/inboxes.ex` | `SettingsLive.Inboxes` |

Segmento fixo vira pasta/arquivo (`-` → `_`), `:param` vira `show`, raiz da pasta vira `index`.
Um LiveView por rota; lógica compartilhada entre páginas da mesma pasta vai num módulo auxiliar
nela (ex.: `live/companies/form_modal.ex`, via `on_mount`). As rotas continuam explícitas no router.

- Um componente público por arquivo: `ChatwooterWeb.Components.<Área>.<Nome>`, nome de função único no app
  (base genérico leva prefixo `next_`). Passou de ~250 linhas, quebre.
- `next/*` usa `use ChatwooterWeb, :base_component`; as demais áreas, `use ChatwooterWeb, :component`.
  Irmãos são importados explicitamente. Nunca `use ChatwooterWeb, :html` em componente (ciclo de compilação).
- Estado fica no LiveView; componentes recebem `attr` explícitos e disparam eventos. Sem LiveComponent.
- Hooks JS colocalizados ficam no componente que os usa; `phx-hook=".Nome"` só resolve no próprio módulo,
  então reutilize encapsulando num componente.

## Port 1:1 do Chatwoot

- O `.vue` é a fonte da verdade: estrutura, classes Tailwind, textos do `i18n/locale/en` e comportamento.
  Aponte o `.vue` no `@moduledoc`. Desvio só com comentário explicando o porquê.
- Sem backend ainda? O elemento aparece só visual, com comentário HEEx — nunca link quebrado.
- Ícones: **só Phosphor** (`ph-<nome>`, `ph-<nome>-<peso>`); confira se existe em `deps/phosphor/raw/`.

## CSS

- Tailwind v4, sem `@apply` (utilitários próprios com `@utility` em `app.css`).
- Cor só via tokens de `assets/css/tokens.css`, nunca hex no template: paleta `n-*` do Chatwoot nas telas
  portadas; `brand/ink/canvas/surface/...` nas antigas. Não use nomes da daisyUI (`primary`, `base-*`...).

## Comentários

Só quando explicam o *porquê* (decisão, contexto, armadilha). Nada que repita o código.

---

## Phoenix / Elixir — armadilhas

**LiveView e rotas**
- Templates começam com `<Layouts.app flash={@flash} current_scope={@current_scope}>`; `<.flash_group>` só em `layouts.ex`.
- Usuário logado é `@current_scope.user` (não existe `@current_user`); passe `current_scope` aos contexts.
- Rotas autenticadas entram no `live_session :dashboard` existente; públicas com usuário opcional no `:current_user`.
  Nunca duplique nomes de `live_session`. Diga em que escopo colocou a rota e por quê.
- `<.link navigate/patch>` e `push_navigate/push_patch` (nunca `live_redirect`/`live_patch`).
- Coleções em streams: pai com `phx-update="stream"` e id; filtrar = refazer o stream com `reset: true`;
  contagem e vazio exigem assign próprio.
- Hook com `phx-hook` precisa de id único; se o hook controla o DOM, use `phx-update="ignore"`.
  Scripts só como hook colocalizado (`<script :type={Phoenix.LiveView.ColocatedHook} name=".Nome">`).

**HEEx**
- Atributos com `{...}`; blocos (`if`, `for`, `cond`) no corpo com `<%= ... %>`; comentários `<%!-- --%>`.
- Várias classes sempre em lista: `class={["a", @x && "b", if(@y, do: "c", else: "d")]}`.
- Não existe `else if`: use `cond`/`case`. Para gerar conteúdo use `for`/`:for`, nunca `Enum.each`.

**Formulários**
- Sempre `to_form/2` no LiveView e `<.form for={@form} id="...">` + `@form[:campo]`; nunca o changeset no template.
- Inputs: `<.next_input>` nas telas portadas, `<.input>` do core no resto.

**Elixir / Ecto**
- Lista não aceita `lista[i]` (use `Enum.at`); struct não aceita `struct[:campo]`.
- Resultado de `if`/`case` precisa ser atribuído fora do bloco (não rebinde dentro).
- Nada de `String.to_atom/1` em entrada de usuário. Predicados terminam em `?` (sem `is_`).
- Preload das associações usadas no template; `Ecto.Changeset.get_field/2` para ler changeset.
- Campos definidos pelo sistema (`user_id`, `account_id`...) não entram no `cast`.
- Migrations sempre com `mix ecto.gen.migration nome_com_underscores`.

**Testes**
- Processos com `start_supervised!/1`; nada de `Process.sleep/1` — use `Process.monitor/1` + `assert_receive`
  ou `:sys.get_state/1`.
- Depurar seletor: `LazyHTML.from_fragment(render(view)) |> LazyHTML.filter("seletor")`.
