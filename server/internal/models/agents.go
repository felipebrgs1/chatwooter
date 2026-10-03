package models

import "context"

// Agents é a lista de agentes da conta (AgentsController#index).
type Agents struct{ db DB }

func NewAgents(db DB) *Agents { return &Agents{db: db} }

// List devolve os usuários da conta em order_by_full_name (lower(name)).
func (a *Agents) List(ctx context.Context, accountID int32) ([]Agent, error) {
	return a.list(ctx, accountID, `SELECT u.id FROM users u JOIN account_users au ON au.user_id = u.id
		WHERE au.account_id = $1 ORDER BY lower(u.name), u.id`, accountID)
}

// list carrega os agentes cujos ids a query devolve, na ordem dela.
func (a *Agents) list(ctx context.Context, accountID int32, sql string, args ...any) ([]Agent, error) {
	rows, err := a.db.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
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

// Assignable é o AssignableAgentsController#index: quem é membro de todas as inboxes pedidas, mais os
// administradores da conta. Inbox fora da conta (ou nenhuma) = ErrNotFound, como o `find` do Rails.
func (a *Agents) Assignable(ctx context.Context, accountID int32, inboxIDs []int32) ([]Agent, error) {
	var found int
	if err := a.db.QueryRow(ctx, `SELECT count(*) FROM inboxes WHERE account_id = $1 AND id = ANY($2)`,
		accountID, inboxIDs).Scan(&found); err != nil {
		return nil, err
	}
	if len(inboxIDs) == 0 || found != len(uniqueIDs(inboxIDs)) {
		return nil, ErrNotFound
	}
	return a.list(ctx, accountID, `SELECT u.id FROM users u JOIN account_users au ON au.user_id = u.id
		WHERE au.account_id = $1 AND (au.role = 1 OR NOT EXISTS (
			SELECT 1 FROM unnest($2::int[]) AS i(id)
			WHERE NOT EXISTS (SELECT 1 FROM inbox_members m WHERE m.inbox_id = i.id AND m.user_id = u.id)))
		ORDER BY lower(u.name), u.id`, accountID, inboxIDs)
}

func uniqueIDs(ids []int32) map[int32]bool {
	out := map[int32]bool{}
	for _, id := range ids {
		out[id] = true
	}
	return out
}
