# Chatwooter — guia para agentes

Reimplementação do Chatwoot como API Go (`server/`) + dashboard React (`web/`). Visão: `ROTEIRO.md`;
andamento da migração: `ROADMAP_MIGRACAO_GO_REACT.md`; o que falta para ficar 1:1 (checklist, em ordem):
`ROADMAP_PARIDADE_PRODUTO.md` — marque os itens ao concluir.
`chatwoot/` é a referência read-only do original (Rails + Vue) — **nunca editar**.
Escopo v1: só WhatsApp Cloud API + Telegram Bot API. A versão Elixir antiga está na tag `elixir-final`
(consulta apenas; não volta para a árvore).

## Comandos

Na raiz: `make precommit` (gate), `make test`, `make fmt`, `make sqlc`, `make migrate`, `make seed`,
`make schema-diff`, `make i18n-sync`. Testes do Go precisam de Postgres: `docker compose up -d db` (porta `5434`,
`TEST_DATABASE_URL` já vem do Makefile). Stack de dev: `docker compose up` (API `:4100`, web `:5173`;
login `john@acme.inc` / `Password123!`).

## Backend (MVC)

`router → controllers → models`, resposta em `views` (regras impostas pelo `depguard` em `server/.golangci.yml`).
- Controller nunca importa `pgx`/`db`; model nunca importa `net/http`; view só serializa os tipos dos models (nunca banco, controller ou router).
- SQL fica em `internal/db/queries/*.sql` e vira código com `sqlc`; só `models` usa o código gerado.
  Não edite `internal/db/sqlc/`. Schema novo = migration `goose` nova em `internal/db/migrations`, nunca editar o baseline.
- O schema tem de continuar idêntico ao `schema.rb` do Chatwoot: `internal/schemaparity` é o gate.
- Rotas e JSON iguais aos do Chatwoot: a view espelha o `.jbuilder` (aponte-o no comentário do tipo).
  Desvio (ex.: segredo que o Chatwoot expõe) só com comentário explicando o porquê.
- Toda query de dados é escopada pela conta (`account_id`); o papel (`administrator`/`agent`) segue as policies do Chatwoot.
- Dados de teste: `internal/factory`; banco real descartável por teste: `internal/testdb`. Sem mocks de banco.
- Segredos (tokens de canal) só via `models.InboxConfigs` (AES-GCM); nunca logar, guardar em claro nem devolver na API.
- Jobs com efeito externo só pelo River (`internal/jobs`); worker novo entra em `jobs.Workers()`.

## Frontend

- Rota = arquivo em `src/routes` (TanStack Router); `routeTree.gen.ts` é gerado, não edite.
- Textos vêm do i18n (`t('CHAVE.DO.CHATWOOT')`), só `en` e `pt_BR`; nunca string fixa na tela.
  Sintaxe vue-i18n (`{var}`, `a | b`) já é tratada. Atualizou a referência? `make i18n-sync`.
- Um `tsconfig.json` só. Chamadas à API em `src/api/` (uma `queryOptions` por recurso, chave por conta).
- Base genérica do Chatwoot (`components-next`) em `src/components/next/`; o resto por área (`sidebar/`, `conversation/`...).
  Estado fica nas rotas/hooks; componentes recebem props e avisam por callbacks.

## TDD (obrigatório)

1. **Red** — teste do comportamento; rode e veja falhar pelo motivo certo.
2. **Green** — o mínimo de código para passar.
3. **Refactor** — com a suíte verde.
4. **`make precommit`** verde (formatação, lint, typecheck, testes) antes de dar como pronto.

- Bug: primeiro o teste que o reproduz. Refatoração pura não altera testes.
- Go: `*_test.go` ao lado do código, pacote `_test`; rotas testadas pelo router real (`internal/router/*_test.go`).
- Web: Vitest + Testing Library + MSW (`src/test/server.ts`); ache elementos por papel/texto, não por implementação;
  teste o resultado, não a implementação.
- Tela nova ou alterada: confira também no browser.

## Port 1:1 do Chatwoot

- O `.vue` é a fonte da verdade: estrutura, classes Tailwind, textos do `i18n/locale/en` e comportamento.
  Aponte o `.vue` no comentário do topo do componente. Desvio só com comentário explicando o porquê.
- Sem backend ainda? O elemento aparece só visual, com comentário — nunca link quebrado.
- Ícones: **só Phosphor** (`ph-<nome>`, `ph-<nome>-<peso>`), registrados em `src/components/next/icon.tsx`.

## CSS

- Tailwind v4, sem `@apply` (utilitários próprios com `@utility` em `src/styles/app.css`).
- Cor só via tokens de `src/styles/tokens.css` (paleta `n-*` do Chatwoot), nunca hex no template.
  A exceção é cor que vem do banco (ex.: `labels.color`), aplicada por `style`.

## Comentários

Só quando explicam o *porquê* (decisão, contexto, armadilha). Nada que repita o código.
