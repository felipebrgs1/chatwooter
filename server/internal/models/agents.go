package models

import "context"

// Agents é a lista de agentes da conta (AgentsController#index).
type Agents struct{ db DB }

func NewAgents(db DB) *Agents { return &Agents{db: db} }

// List devolve os usuários da conta em order_by_full_name (lower(name)).
func (a *Agents) List(ctx context.Context, accountID int32) ([]Agent, error) {
	rows, err := a.db.Query(ctx, `SELECT u.id FROM users u JOIN account_users au ON au.user_id = u.id
		WHERE au.account_id = $1 ORDER BY lower(u.name), u.id`, accountID)
	if err != nil {
		return nil, err
	}
	var ids []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	byID, err := agentsByID(ctx, a.db, accountID, ids)
	if err != nil {
		return nil, err
	}
	out := make([]Agent, 0, len(ids))
	for _, id := range ids {
		out = append(out, byID[id])
	}
	return out, nil
}
