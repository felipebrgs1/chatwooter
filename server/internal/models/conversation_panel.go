package models

import (
	"context"
	"strings"
)

// TogglePriority é o Conversation#toggle_priority: vazio ou nulo limpa (priority.presence).
func (c *Conversations) TogglePriority(ctx context.Context, accountID, displayID int32, priority *string) error {
	var value *int32
	if priority != nil && *priority != "" {
		v, ok := priorityValues[*priority]
		if !ok {
			return ErrInvalid
		}
		value = &v
	}
	tag, err := c.db.Exec(ctx, `UPDATE conversations SET priority = $3, updated_at = now() AT TIME ZONE 'utc'
		WHERE account_id = $1 AND display_id = $2`, accountID, displayID, value)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Labels é o label_list da conversa (conversations/labels#index).
func (c *Conversations) Labels(ctx context.Context, accountID, displayID int32) ([]string, error) {
	id, _, err := c.internalID(ctx, accountID, displayID)
	if err != nil {
		return nil, err
	}
	return labelsOf(ctx, c.db, "Conversation", id)
}

// SetLabels é o update_labels da conversa. O acts_as_taggable_on guarda a lista em cached_label_list ("a, b"),
// que a lista de conversas usa para os cards.
func (c *Conversations) SetLabels(ctx context.Context, accountID, displayID int32, labels []string) ([]string, error) {
	id, _, err := c.internalID(ctx, accountID, displayID)
	if err != nil {
		return nil, err
	}
	tx, err := c.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	list, err := setLabels(ctx, tx, "Conversation", id, labels)
	if err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx, `UPDATE conversations SET cached_label_list = $2, updated_at = now() AT TIME ZONE 'utc' WHERE id = $1`,
		id, strings.Join(list, ", ")); err != nil {
		return nil, err
	}
	return list, tx.Commit(ctx)
}
