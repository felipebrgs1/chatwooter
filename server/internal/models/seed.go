package models

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"

	"golang.org/x/crypto/bcrypt"
)

// Login de desenvolvimento, o mesmo do seed do Chatwoot (conta "Acme Inc").
const (
	DevSeedEmail    = "john@acme.inc"
	DevSeedPassword = "Password123!"
)

// SeedDev garante o usuário administrador de desenvolvimento e a conta dele. Idempotente: só cria o que falta.
// Nunca roda em produção por conta própria; é o comando `seed` do binário.
func SeedDev(ctx context.Context, db DB) error {
	tx, err := db.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var userID int32
	err = tx.QueryRow(ctx, `SELECT id FROM users WHERE lower(email) = lower($1)`, DevSeedEmail).Scan(&userID)
	if err != nil {
		hash, err := bcrypt.GenerateFromPassword([]byte(DevSeedPassword), bcrypt.DefaultCost)
		if err != nil {
			return err
		}
		pubsub, err := randomToken()
		if err != nil {
			return err
		}
		err = tx.QueryRow(ctx, `INSERT INTO users (name, email, uid, encrypted_password, pubsub_token, confirmed_at, created_at, updated_at)
			VALUES ('John', $1, $1, $2, $3, now(), now(), now()) RETURNING id`, DevSeedEmail, string(hash), pubsub).Scan(&userID)
		if err != nil {
			return fmt.Errorf("seed: usuário: %w", err)
		}
	}

	var hasToken bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM access_tokens WHERE owner_type = 'User' AND owner_id = $1)`,
		userID).Scan(&hasToken); err != nil {
		return err
	}
	if !hasToken {
		token, err := randomToken()
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `INSERT INTO access_tokens (owner_type, owner_id, token, created_at, updated_at)
			VALUES ('User', $1, $2, now(), now())`, userID, token); err != nil {
			return fmt.Errorf("seed: access token: %w", err)
		}
	}

	var hasAccount bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM account_users WHERE user_id = $1)`, userID).Scan(&hasAccount); err != nil {
		return err
	}
	if !hasAccount {
		var accountID int32
		if err := tx.QueryRow(ctx, `INSERT INTO accounts (name, created_at, updated_at) VALUES ('Acme Inc', now(), now()) RETURNING id`).
			Scan(&accountID); err != nil {
			return fmt.Errorf("seed: conta: %w", err)
		}
		// role 1 = administrator (enum do AccountUser)
		if _, err := tx.Exec(ctx, `INSERT INTO account_users (account_id, user_id, role, created_at, updated_at)
			VALUES ($1, $2, 1, now(), now())`, accountID, userID); err != nil {
			return fmt.Errorf("seed: vínculo: %w", err)
		}
	}
	return tx.Commit(ctx)
}

func randomToken() (string, error) {
	raw := make([]byte, 12)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	return hex.EncodeToString(raw), nil
}
