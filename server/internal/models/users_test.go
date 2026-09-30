package models_test

import (
	"context"
	"errors"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

func TestAuthenticate(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	users := models.NewUsers(pool)
	account := f.Account()
	agent := f.User(account, func(u *factory.User) { u.Email = "Ana@Example.com" })

	t.Run("senha correta, e-mail sem distinguir maiúsculas", func(t *testing.T) {
		got, err := users.Authenticate(ctx, "ana@example.COM", factory.DefaultPassword)
		if err != nil {
			t.Fatal(err)
		}
		if got.ID != agent.ID {
			t.Errorf("ID = %d, want %d", got.ID, agent.ID)
		}
	})

	for name, c := range map[string]struct{ email, password string }{
		"senha errada":        {"ana@example.com", "errada"},
		"usuário inexistente": {"ninguem@example.com", factory.DefaultPassword},
		"senha vazia":         {"ana@example.com", ""},
		"e-mail vazio":        {"", factory.DefaultPassword},
	} {
		t.Run(name, func(t *testing.T) {
			if _, err := users.Authenticate(ctx, c.email, c.password); !errors.Is(err, models.ErrInvalidCredentials) {
				t.Errorf("err = %v, want ErrInvalidCredentials", err)
			}
		})
	}
}

// Dump do Chatwoot: o Devise guarda senha vazia para contas que entram por SSO.
func TestAuthenticateRejectsEmptyStoredPassword(t *testing.T) {
	pool, f := migratedPool(t)
	account := f.Account()
	f.User(account, func(u *factory.User) { u.Email = "sso@example.com" })
	if _, err := pool.Exec(context.Background(), `UPDATE users SET encrypted_password = '' WHERE email = 'sso@example.com'`); err != nil {
		t.Fatal(err)
	}
	if _, err := models.NewUsers(pool).Authenticate(context.Background(), "sso@example.com", ""); !errors.Is(err, models.ErrInvalidCredentials) {
		t.Errorf("err = %v", err)
	}
	if _, err := models.NewUsers(pool).Authenticate(context.Background(), "sso@example.com", "qualquer"); !errors.Is(err, models.ErrInvalidCredentials) {
		t.Errorf("err = %v", err)
	}
}

// Dumps restaurados podem ter e-mails repetidos: nunca autenticar uma identidade arbitrária.
func TestAuthenticateRejectsAmbiguousEmail(t *testing.T) {
	pool, f := migratedPool(t)
	account := f.Account()
	f.User(account, func(u *factory.User) { u.Email = "dup@example.com" })
	f.User(account, func(u *factory.User) { u.Email = "dup@example.com"; u.UID = "outro-uid" })
	if _, err := models.NewUsers(pool).Authenticate(context.Background(), "dup@example.com", factory.DefaultPassword); !errors.Is(err, models.ErrInvalidCredentials) {
		t.Errorf("err = %v", err)
	}
}

func TestUserByAccessToken(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	agent := f.User(f.Account())
	users := models.NewUsers(pool)

	got, err := users.ByAccessToken(ctx, agent.AccessToken)
	if err != nil || got.ID != agent.ID {
		t.Fatalf("ByAccessToken = %+v, %v", got, err)
	}
	for _, bad := range []string{"", "token-inexistente"} {
		if _, err := users.ByAccessToken(ctx, bad); !errors.Is(err, models.ErrNotFound) {
			t.Errorf("ByAccessToken(%q) err = %v, want ErrNotFound", bad, err)
		}
	}
}
