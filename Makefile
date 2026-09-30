.PHONY: precommit test server-test web-test lint fmt sqlc migrate seed schema-diff i18n-sync

# Banco de teste: o servidor do compose (precisa poder criar bancos).
TEST_DATABASE_URL ?= postgres://postgres:postgres@localhost:5434/postgres?sslmode=disable
export TEST_DATABASE_URL

precommit: fmt-check lint test

fmt:
	cd server && go tool golangci-lint fmt ./...
	cd web && npm run format

fmt-check:
	cd server && test -z "$$(go tool golangci-lint fmt --diff ./... )"
	cd web && npm run format:check

lint:
	cd server && go vet ./... && go tool golangci-lint run ./...
	cd web && npm run lint && npm run typecheck

test: server-test web-test

server-test:
	cd server && go test ./...

web-test:
	cd web && npm test

sqlc:
	cd server && go tool sqlc generate

# Aplica as migrations no banco de desenvolvimento (adota o schema se ele já existir).
migrate:
	cd server && DATABASE_URL='postgres://postgres:postgres@localhost:5434/chatwooter_dev?sslmode=disable' go run ./cmd/chatwooter migrate

# Usuário de desenvolvimento john@acme.inc / Password123! (idempotente; o compose já roda na subida).
seed:
	cd server && DATABASE_URL='postgres://postgres:postgres@localhost:5434/chatwooter_dev?sslmode=disable' go run ./cmd/chatwooter seed

i18n-sync:
	cd web && npm run i18n:sync

# Compara o banco de desenvolvimento ao schema.rb do Chatwoot (diagnóstico).
schema-diff:
	cd server && DATABASE_URL='postgres://postgres:postgres@localhost:5434/chatwooter_dev?sslmode=disable' go run ./cmd/schemadiff
