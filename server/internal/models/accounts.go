package models

import (
	"context"
	"encoding/json"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
)

type Account struct {
	ID               int32
	Name             string
	Locale           string
	Domain           string
	SupportEmail     string
	Status           string
	Settings         json.RawMessage
	CustomAttributes json.RawMessage
	CreatedAt        time.Time
}

type Accounts struct {
	q *sqlc.Queries
}

func NewAccounts(db sqlc.DBTX) *Accounts { return &Accounts{q: sqlc.New(db)} }

func (a *Accounts) ByID(ctx context.Context, id int32) (Account, error) {
	row, err := a.q.GetAccount(ctx, id)
	if err != nil {
		return Account{}, notFound(err)
	}
	return Account{
		ID:               row.ID,
		Name:             row.Name,
		Locale:           localeCode(row.Locale.Int32),
		Domain:           row.Domain.String,
		SupportEmail:     row.SupportEmail.String,
		Status:           accountStatus(row.Status.Int32),
		Settings:         orEmptyObject(row.Settings),
		CustomAttributes: orEmptyObject(row.CustomAttributes),
		CreatedAt:        row.CreatedAt,
	}, nil
}
