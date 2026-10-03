package models

import (
	"context"
	"slices"
	"time"
)

// BulkUpdate são os parâmetros de conversa do bulk_actions. Campo nil não muda; Unassign/ClearTeam pedem
// explicitamente o nulo (o `fields: { assignee_id: nil }` do Chatwoot).
type BulkUpdate struct {
	IDs          []int32 // display_id
	Status       *string
	SnoozedUntil *time.Time
	AssigneeID   *int32
	Unassign     bool
	TeamID       *int32
	LabelsAdd    []string
	LabelsRemove []string
}

// BulkUpdate é o BulkActionsJob, na mesma ordem: primeiro tira as etiquetas de todas, depois, conversa a
// conversa, põe as novas e atualiza status, agente e time. Só entram as conversas que o usuário enxerga
// (PermissionFilterService). Desvio v1: roda na requisição, não num job.
func (c *Conversations) BulkUpdate(ctx context.Context, accountID, userID int32, admin bool, in BulkUpdate) error {
	ids, err := c.accessibleDisplayIDs(ctx, accountID, userID, admin, in.IDs)
	if err != nil {
		return err
	}
	if len(in.LabelsRemove) > 0 {
		for _, id := range ids {
			if err := c.changeLabels(ctx, accountID, id, func(current []string) []string {
				return withoutLabels(current, in.LabelsRemove)
			}); err != nil {
				return err
			}
		}
	}
	for _, id := range ids {
		if len(in.LabelsAdd) > 0 {
			if err := c.changeLabels(ctx, accountID, id, func(current []string) []string {
				return append(current, in.LabelsAdd...)
			}); err != nil {
				return err
			}
		}
		if in.Status != nil {
			if _, err := c.ToggleStatus(ctx, accountID, id, *in.Status, in.SnoozedUntil); err != nil {
				return err
			}
		}
		if in.AssigneeID != nil || in.Unassign {
			if _, err := c.AssignAgent(ctx, accountID, id, in.AssigneeID); err != nil {
				return err
			}
		}
		if in.TeamID != nil {
			if _, err := c.AssignTeam(ctx, accountID, id, in.TeamID); err != nil {
				return err
			}
		}
	}
	return nil
}

func (c *Conversations) accessibleDisplayIDs(ctx context.Context, accountID, userID int32, admin bool, ids []int32) ([]int32, error) {
	rows, err := c.db.Query(ctx, `SELECT display_id FROM conversations WHERE account_id = $1 AND display_id = ANY($2)
		AND ($3 OR inbox_id IN (SELECT inbox_id FROM inbox_members WHERE user_id = $4)) ORDER BY display_id`,
		accountID, ids, admin, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []int32{}
	for rows.Next() {
		var id int32
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

func (c *Conversations) changeLabels(ctx context.Context, accountID, displayID int32, change func([]string) []string) error {
	current, err := c.Labels(ctx, accountID, displayID)
	if err != nil {
		return err
	}
	_, err = c.SetLabels(ctx, accountID, displayID, change(current))
	return err
}

// withoutLabels é o `label_list - remove` do Ruby: comparação exata.
func withoutLabels(current, remove []string) []string {
	out := []string{}
	for _, label := range current {
		if !slices.Contains(remove, label) {
			out = append(out, label)
		}
	}
	return out
}
