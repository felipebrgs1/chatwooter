package models_test

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/felipeborgaco/chatwooter/server/internal/db"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/secrets"
	"github.com/felipeborgaco/chatwooter/server/internal/testdb"
)

func setup(t *testing.T) (*models.InboxConfigs, *pgxpool.Pool) {
	t.Helper()
	pool := testdb.New(t)
	if err := db.Migrate(context.Background(), pool); err != nil {
		t.Fatal(err)
	}
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		t.Fatal(err)
	}
	box, err := secrets.NewBox(key)
	if err != nil {
		t.Fatal(err)
	}
	return models.NewInboxConfigs(pool, box), pool
}

func rawConfig(t *testing.T, pool *pgxpool.Pool, inboxID int32) string {
	t.Helper()
	var raw string
	err := pool.QueryRow(context.Background(),
		`SELECT provider_config::text FROM chatwooter_inbox_configs WHERE inbox_id = $1`, inboxID).Scan(&raw)
	if err != nil {
		t.Fatal(err)
	}
	return raw
}

func TestPutEncryptsAndGetDecrypts(t *testing.T) {
	cfgs, pool := setup(t)
	ctx := context.Background()

	if err := cfgs.Put(ctx, 1, map[string]any{"bot_token": "123:abc"}); err != nil {
		t.Fatal(err)
	}
	if raw := rawConfig(t, pool, 1); strings.Contains(raw, "123:abc") {
		t.Fatalf("token em texto claro no banco: %s", raw)
	}
	got, err := cfgs.Get(ctx, 1)
	if err != nil {
		t.Fatal(err)
	}
	if got["bot_token"] != "123:abc" {
		t.Errorf("Get = %v", got)
	}
}

func TestPutOverwritesPreviousConfig(t *testing.T) {
	cfgs, _ := setup(t)
	ctx := context.Background()
	_ = cfgs.Put(ctx, 1, map[string]any{"a": "1"})
	_ = cfgs.Put(ctx, 1, map[string]any{"b": "2"})
	got, _ := cfgs.Get(ctx, 1)
	if _, ok := got["a"]; ok || got["b"] != "2" {
		t.Errorf("Get = %v", got)
	}
}

func TestGetMissingIsEmpty(t *testing.T) {
	cfgs, _ := setup(t)
	got, err := cfgs.Get(context.Background(), 99)
	if err != nil || len(got) != 0 {
		t.Fatalf("Get = %v, %v", got, err)
	}
}

func TestGetReadsLegacyPlaintext(t *testing.T) {
	cfgs, pool := setup(t)
	legacy, _ := json.Marshal(map[string]any{"bot_token": "legacy"})
	if _, err := pool.Exec(context.Background(),
		`INSERT INTO chatwooter_inbox_configs (inbox_id, provider_config) VALUES (7, $1)`, legacy); err != nil {
		t.Fatal(err)
	}
	got, err := cfgs.Get(context.Background(), 7)
	if err != nil || got["bot_token"] != "legacy" {
		t.Fatalf("Get = %v, %v", got, err)
	}
}

func TestEncryptLegacyMigratesOnlyPlaintextRows(t *testing.T) {
	cfgs, pool := setup(t)
	ctx := context.Background()
	for id, body := range map[int]string{1: `{"bot_token":"t1"}`, 2: `{"bot_token":"t2"}`, 3: `{}`} {
		if _, err := pool.Exec(ctx,
			`INSERT INTO chatwooter_inbox_configs (inbox_id, provider_config) VALUES ($1, $2::jsonb)`, id, body); err != nil {
			t.Fatal(err)
		}
	}
	if err := cfgs.Put(ctx, 4, map[string]any{"bot_token": "já cifrado"}); err != nil {
		t.Fatal(err)
	}

	n, err := cfgs.EncryptLegacy(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if n != 2 {
		t.Errorf("migrou %d, want 2 (vazio e já cifrado ficam de fora)", n)
	}
	for _, id := range []int32{1, 2, 4} {
		if raw := rawConfig(t, pool, id); strings.Contains(raw, "bot_token") {
			t.Errorf("inbox %d ainda em texto claro: %s", id, raw)
		}
	}
	if got, _ := cfgs.Get(ctx, 2); got["bot_token"] != "t2" {
		t.Errorf("valor mudou depois de cifrar: %v", got)
	}
	again, _ := cfgs.EncryptLegacy(ctx)
	if again != 0 {
		t.Errorf("segunda execução migrou %d, want 0", again)
	}
}
