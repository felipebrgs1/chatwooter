package db_test

import (
	"context"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/db"
	"github.com/felipeborgaco/chatwooter/server/internal/testdb"
)

func TestMigrateAppliesBaseline(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()

	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatal(err)
	}
	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatalf("segunda execução deve ser no-op: %v", err)
	}

	var tables int
	err := pool.QueryRow(ctx, `SELECT count(*) FROM pg_tables
		WHERE schemaname = 'public' AND tablename <> 'goose_db_version' AND tablename NOT LIKE 'river_%'`).Scan(&tables)
	if err != nil {
		t.Fatal(err)
	}
	var river int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM pg_tables WHERE tablename = 'river_job'`).Scan(&river); err != nil {
		t.Fatal(err)
	}
	if river != 1 {
		t.Error("tabela river_job ausente: migrations do River não rodaram")
	}
	if tables != 109 {
		t.Errorf("tabelas = %d, want 109", tables)
	}
}

// Banco já populado pelo app Elixir (ou restaurado de um dump): o baseline é registrado, nunca reaplicado.
func TestMigrateAdoptsDatabaseThatAlreadyHasTheSchema(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	for _, ddl := range []string{
		`CREATE TABLE accounts (id serial PRIMARY KEY, name text)`,
		`CREATE TABLE conversations (id serial PRIMARY KEY)`,
		`CREATE TABLE users (id serial PRIMARY KEY)`,
		`INSERT INTO accounts (name) VALUES ('existente')`,
	} {
		if _, err := pool.Exec(ctx, ddl); err != nil {
			t.Fatal(err)
		}
	}

	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatalf("banco existente deveria ser adotado: %v", err)
	}

	var name string
	if err := pool.QueryRow(ctx, `SELECT name FROM accounts`).Scan(&name); err != nil || name != "existente" {
		t.Fatalf("dados foram perdidos: %q, %v", name, err)
	}
	var applied bool
	if err := pool.QueryRow(ctx, `SELECT is_applied FROM goose_db_version WHERE version_id = 1`).Scan(&applied); err != nil || !applied {
		t.Errorf("baseline não foi registrado: %v", err)
	}
	var river int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM pg_tables WHERE tablename = 'river_job'`).Scan(&river); err != nil || river != 1 {
		t.Errorf("migrations do River deveriam rodar mesmo assim (%d, %v)", river, err)
	}
}
