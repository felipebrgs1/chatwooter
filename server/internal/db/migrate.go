// Package db cuida do schema: migrations embutidas (goose) e, nas próximas fases, as queries sqlc.
package db

import (
	"context"
	"database/sql"
	"embed"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
	"github.com/riverqueue/river/rivermigrate"
)

//go:embed migrations/*.sql
var migrations embed.FS

func Migrate(ctx context.Context, pool *pgxpool.Pool) error {
	goose.SetBaseFS(migrations)
	if err := goose.SetDialect("postgres"); err != nil {
		return err
	}
	sqlDB := stdlib.OpenDBFromPool(pool)
	defer func() { _ = sqlDB.Close() }()
	if err := adoptExistingSchema(ctx, pool, sqlDB); err != nil {
		return err
	}
	if err := goose.UpContext(ctx, sqlDB, "migrations"); err != nil {
		return err
	}
	return migrateRiver(ctx, pool)
}

// baselineVersion é a migration que cria todo o schema do Chatwoot.
const baselineVersion = 1

// adoptExistingSchema registra o baseline como aplicado num banco que já tem o schema (criado pelo app Elixir
// ou restaurado de um dump do Chatwoot). Nunca reaplicamos as migrations de criação sobre tabelas existentes.
func adoptExistingSchema(ctx context.Context, pool *pgxpool.Pool, sqlDB *sql.DB) error {
	var tracked, populated bool
	err := pool.QueryRow(ctx, `SELECT
		to_regclass('goose_db_version') IS NOT NULL,
		to_regclass('accounts') IS NOT NULL AND to_regclass('conversations') IS NOT NULL`).Scan(&tracked, &populated)
	if err != nil || tracked || !populated {
		return err
	}
	if _, err := goose.EnsureDBVersionContext(ctx, sqlDB); err != nil {
		return err
	}
	_, err = pool.Exec(ctx, `INSERT INTO goose_db_version (version_id, is_applied) VALUES ($1, true)`, baselineVersion)
	return err
}

// As tabelas do River têm migrator próprio; rodam depois do baseline.
func migrateRiver(ctx context.Context, pool *pgxpool.Pool) error {
	m, err := rivermigrate.New(riverpgxv5.New(pool), nil)
	if err != nil {
		return err
	}
	_, err = m.Migrate(ctx, rivermigrate.DirectionUp, nil)
	return err
}
