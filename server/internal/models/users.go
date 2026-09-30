package models

import (
	"context"
	"encoding/json"
	"errors"
	"sync"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
)

type User struct {
	ID               int32
	Name             string
	DisplayName      string
	Email            string
	UID              string
	Provider         string
	Type             string
	MessageSignature string
	PubsubToken      string
	Confirmed        bool
	UISettings       json.RawMessage
	CustomAttributes json.RawMessage
}

// AvailableName é o nome mostrado na interface: display_name quando existe, senão name.
func (u User) AvailableName() string {
	if u.DisplayName != "" {
		return u.DisplayName
	}
	return u.Name
}

type Users struct {
	q *sqlc.Queries
}

func NewUsers(db sqlc.DBTX) *Users { return &Users{q: sqlc.New(db)} }

func userFrom(u sqlc.User) User {
	return User{
		ID:               u.ID,
		Name:             u.Name,
		DisplayName:      u.DisplayName.String,
		Email:            u.Email.String,
		UID:              u.Uid,
		Provider:         u.Provider,
		Type:             u.Type.String,
		MessageSignature: u.MessageSignature.String,
		PubsubToken:      u.PubsubToken.String,
		Confirmed:        u.ConfirmedAt != nil,
		UISettings:       orEmptyObject(u.UiSettings),
		CustomAttributes: orEmptyObject(u.CustomAttributes),
	}
}

func orEmptyObject(raw []byte) json.RawMessage {
	if len(raw) == 0 {
		return json.RawMessage("{}")
	}
	return raw
}

// dummyHash existe para que e-mail inexistente custe o mesmo que senha errada (evita enumerar usuários por tempo).
var dummyHash = sync.OnceValue(func() []byte {
	h, err := bcrypt.GenerateFromPassword([]byte("dummy"), bcrypt.DefaultCost)
	if err != nil {
		panic(err)
	}
	return h
})

// Authenticate valida e-mail e senha contra o hash do Devise ($2a$). E-mail repetido (comum em dumps
// restaurados) nunca autentica: não escolhemos uma identidade arbitrária.
func (u *Users) Authenticate(ctx context.Context, email, password string) (User, error) {
	var found []sqlc.User
	if email != "" {
		var err error
		if found, err = u.q.UsersByEmail(ctx, email); err != nil {
			return User{}, err
		}
	}
	if len(found) != 1 || found[0].EncryptedPassword == "" || password == "" {
		_ = bcrypt.CompareHashAndPassword(dummyHash(), []byte(password))
		return User{}, ErrInvalidCredentials
	}
	if bcrypt.CompareHashAndPassword([]byte(found[0].EncryptedPassword), []byte(password)) != nil {
		return User{}, ErrInvalidCredentials
	}
	return userFrom(found[0]), nil
}

func (u *Users) ByID(ctx context.Context, id int32) (User, error) {
	row, err := u.q.GetUser(ctx, id)
	if err != nil {
		return User{}, notFound(err)
	}
	return userFrom(row), nil
}

// ByAccessToken resolve o header `api_access_token` da API.
func (u *Users) ByAccessToken(ctx context.Context, token string) (User, error) {
	if token == "" {
		return User{}, ErrNotFound
	}
	row, err := u.q.GetUserByAccessToken(ctx, pgTextPtr(token))
	if err != nil {
		return User{}, notFound(err)
	}
	return userFrom(row.User), nil
}

func notFound(err error) error {
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	return err
}
