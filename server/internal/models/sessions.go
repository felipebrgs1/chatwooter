package models

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"time"

	"github.com/jackc/pgx/v5/pgtype"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
)

// Sessions guarda as sessões do dashboard. O cookie leva o token; o banco só o SHA-256 dele.
type Sessions struct {
	q   *sqlc.Queries
	ttl time.Duration
}

func NewSessions(db sqlc.DBTX, ttl time.Duration) *Sessions {
	return &Sessions{q: sqlc.New(db), ttl: ttl}
}

// TTL é a validade das novas sessões (também usada como Max-Age do cookie).
func (s *Sessions) TTL() time.Duration { return s.ttl }

func hashToken(token string) []byte {
	sum := sha256.Sum256([]byte(token))
	return sum[:]
}

func (s *Sessions) Create(ctx context.Context, userID int32) (string, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	token := base64.RawURLEncoding.EncodeToString(raw)
	err := s.q.InsertSession(ctx, sqlc.InsertSessionParams{
		UserID:    userID,
		TokenHash: hashToken(token),
		ExpiresAt: time.Now().UTC().Add(s.ttl),
	})
	return token, err
}

func (s *Sessions) UserFor(ctx context.Context, token string) (User, error) {
	if token == "" {
		return User{}, ErrNotFound
	}
	row, err := s.q.GetSessionUser(ctx, hashToken(token))
	if err != nil {
		return User{}, notFound(err)
	}
	return userFrom(row.User), nil
}

func (s *Sessions) Revoke(ctx context.Context, token string) error {
	return s.q.DeleteSession(ctx, hashToken(token))
}

func (s *Sessions) PurgeExpired(ctx context.Context) (int64, error) {
	return s.q.PurgeExpiredSessions(ctx)
}

func pgTextPtr(s string) pgtype.Text { return pgtype.Text{String: s, Valid: true} }
