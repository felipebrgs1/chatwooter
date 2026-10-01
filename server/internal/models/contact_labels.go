package models

import "context"

// Etiquetas do contato: ver labelable.go.

func (c *Contacts) exists(ctx context.Context, accountID, id int32) error {
	var ok bool
	if err := c.db.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM contacts WHERE account_id = $1 AND id = $2)`, accountID, id).
		Scan(&ok); err != nil {
		return err
	}
	if !ok {
		return ErrNotFound
	}
	return nil
}

// Labels é o label_list do contato, na ordem das taggings.
func (c *Contacts) Labels(ctx context.Context, accountID, id int32) ([]string, error) {
	if err := c.exists(ctx, accountID, id); err != nil {
		return nil, err
	}
	return labelsOf(ctx, c.db, "Contact", id)
}

// SetLabels é o update_labels do contato.
func (c *Contacts) SetLabels(ctx context.Context, accountID, id int32, labels []string) ([]string, error) {
	if err := c.exists(ctx, accountID, id); err != nil {
		return nil, err
	}
	tx, err := c.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	list, err := setLabels(ctx, tx, "Contact", id, labels)
	if err != nil {
		return nil, err
	}
	return list, tx.Commit(ctx)
}
