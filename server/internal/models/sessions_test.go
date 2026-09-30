package models_test

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

func TestSessionLifecycle(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	agent := f.User(f.Account())
	sessions := models.NewSessions(pool, time.Hour)

	token, err := sessions.Create(ctx, agent.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(token) < 32 {
		t.Fatalf("token curto demais: %q", token)
	}

	var stored string
	if err := pool.QueryRow(ctx, `SELECT encode(token_hash, 'hex') FROM chatwooter_sessions`).Scan(&stored); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(stored, token) || stored == token {
		t.Fatal("o token não pode ficar em claro no banco")
	}

	user, err := sessions.UserFor(ctx, token)
	if err != nil || user.ID != agent.ID {
		t.Fatalf("UserFor = %+v, %v", user, err)
	}

	if err := sessions.Revoke(ctx, token); err != nil {
		t.Fatal(err)
	}
	if _, err := sessions.UserFor(ctx, token); !errors.Is(err, models.ErrNotFound) {
		t.Errorf("sessão revogada: err = %v", err)
	}
}

func TestSessionTokensAreUnique(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	agent := f.User(f.Account())
	sessions := models.NewSessions(pool, time.Hour)
	a, _ := sessions.Create(ctx, agent.ID)
	b, _ := sessions.Create(ctx, agent.ID)
	if a == b {
		t.Fatal("tokens iguais")
	}
}

func TestExpiredSessionIsRejectedAndPurged(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	agent := f.User(f.Account())
	expired := models.NewSessions(pool, -time.Minute)

	token, err := expired.Create(ctx, agent.ID)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := expired.UserFor(ctx, token); !errors.Is(err, models.ErrNotFound) {
		t.Fatalf("sessão expirada: err = %v", err)
	}
	n, err := expired.PurgeExpired(ctx)
	if err != nil || n != 1 {
		t.Errorf("PurgeExpired = %d, %v", n, err)
	}
}

func TestUnknownOrEmptyTokenIsNotFound(t *testing.T) {
	pool, _ := migratedPool(t)
	sessions := models.NewSessions(pool, time.Hour)
	for _, tok := range []string{"", "nao-existe"} {
		if _, err := sessions.UserFor(context.Background(), tok); !errors.Is(err, models.ErrNotFound) {
			t.Errorf("UserFor(%q) err = %v", tok, err)
		}
	}
}
