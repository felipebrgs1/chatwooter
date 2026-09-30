package models

import (
	"context"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
)

type Teams struct {
	q *sqlc.Queries
}

func NewTeams(db sqlc.DBTX) *Teams { return &Teams{q: sqlc.New(db)} }

// List devolve todos os times da conta (TeamPolicy#index? libera qualquer membro), com IsMember do usuário.
func (t *Teams) List(ctx context.Context, accountID, userID int32) ([]Team, error) {
	rows, err := t.q.ListTeams(ctx, sqlc.ListTeamsParams{AccountID: int64(accountID), UserID: int64(userID)})
	if err != nil {
		return nil, err
	}
	out := make([]Team, 0, len(rows))
	for _, r := range rows {
		out = append(out, Team{
			ID:              int32(r.ID), //nolint:gosec // ids integer
			AccountID:       accountID,
			Name:            r.Name,
			Description:     r.Description.String,
			AllowAutoAssign: r.AllowAutoAssign.Bool,
			Icon:            r.Icon.String,
			IconColor:       r.IconColor.String,
			IsMember:        r.IsMember,
		})
	}
	return out, nil
}
