package models_test

import (
	"context"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

func TestSeedDevCreatesTheLoginAndIsIdempotent(t *testing.T) {
	pool, _ := migratedPool(t)
	ctx := context.Background()

	for range 2 {
		if err := models.SeedDev(ctx, pool); err != nil {
			t.Fatal(err)
		}
	}

	user, err := models.NewUsers(pool).Authenticate(ctx, models.DevSeedEmail, models.DevSeedPassword)
	if err != nil {
		t.Fatalf("login do seed: %v", err)
	}
	profile, err := models.NewUsers(pool).Profile(ctx, user.ID)
	if err != nil {
		t.Fatal(err)
	}
	ms := profile.Memberships
	if len(ms) != 1 || ms[0].AccountName != "Acme Inc" || !ms[0].Administrator() {
		t.Fatalf("esperava uma conta Acme Inc como administrador: %+v", ms)
	}
	if profile.AccessToken == "" || profile.User.PubsubToken == "" {
		t.Fatalf("tokens do usuário: access=%q pubsub=%q", profile.AccessToken, profile.User.PubsubToken)
	}
}
