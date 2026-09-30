package router_test

import (
	"context"
	"strconv"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/felipeborgaco/chatwooter/server/internal/db"
)

type testdbPool = pgxpool.Pool

func migrate(t *testing.T, pool *pgxpool.Pool) error {
	t.Helper()
	return db.Migrate(context.Background(), pool)
}

func itoa(id int32) string { return strconv.Itoa(int(id)) }
