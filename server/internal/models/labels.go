package models

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
)

// Label é a etiqueta da conta (tabela labels): título, cor e se aparece na sidebar.
type Label struct {
	ID            int64
	Title         string
	Description   *string
	Color         string
	ShowOnSidebar bool
}

type Labels struct {
	q *sqlc.Queries
}

func NewLabels(db sqlc.DBTX) *Labels { return &Labels{q: sqlc.New(db)} }

// List devolve as etiquetas da conta em ordem de título (o default_scope do Label).
func (l *Labels) List(ctx context.Context, accountID int32) ([]Label, error) {
	rows, err := l.q.ListLabels(ctx, pgtype.Int8{Int64: int64(accountID), Valid: true})
	if err != nil {
		return nil, err
	}
	out := make([]Label, 0, len(rows))
	for _, r := range rows {
		out = append(out, Label{
			ID:            r.ID,
			Title:         r.Title.String,
			Description:   textPtr(r.Description),
			Color:         r.Color,
			ShowOnSidebar: r.ShowOnSidebar.Bool,
		})
	}
	return out, nil
}

func textPtr(t pgtype.Text) *string {
	if !t.Valid {
		return nil
	}
	return &t.String
}
