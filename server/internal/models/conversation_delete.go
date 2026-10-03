package models

import (
	"context"

	"github.com/jackc/pgx/v5"
)

type step struct {
	sql  string
	args []any
}

func execSteps(ctx context.Context, tx pgx.Tx, steps []step) error {
	for _, s := range steps {
		if _, err := tx.Exec(ctx, s.sql, s.args...); err != nil {
			return err
		}
	}
	return nil
}

// purgeConversations apaga as conversas de gone_conversations e as mensagens de gone_messages (tabelas
// temporárias da transação) com o que depende delas: os `dependent:` de Conversation e Message no Chatwoot.
func purgeConversations(ctx context.Context, tx pgx.Tx) error {
	return execSteps(ctx, tx, []step{
		{`DELETE FROM chatwooter_attachment_storage WHERE message_id IN (SELECT id FROM gone_messages)`, nil},
		{`DELETE FROM attachments WHERE message_id IN (SELECT id FROM gone_messages)`, nil},
		{`DELETE FROM notifications WHERE (primary_actor_type = 'Conversation' AND primary_actor_id IN (SELECT id FROM gone_conversations))
			OR (primary_actor_type = 'Message' AND primary_actor_id IN (SELECT id FROM gone_messages))`, nil},
		{`DELETE FROM csat_survey_responses WHERE conversation_id IN (SELECT id FROM gone_conversations)
			OR message_id IN (SELECT id FROM gone_messages)`, nil},
		{`DELETE FROM mentions WHERE conversation_id IN (SELECT id FROM gone_conversations)`, nil},
		{`DELETE FROM conversation_participants WHERE conversation_id IN (SELECT id FROM gone_conversations)`, nil},
		{`DELETE FROM reporting_events WHERE conversation_id IN (SELECT id FROM gone_conversations)`, nil},
		{`DELETE FROM automation_rule_pending_executions WHERE conversation_id IN (SELECT id FROM gone_conversations)`, nil},
		{`DELETE FROM taggings WHERE taggable_type = 'Conversation' AND taggable_id IN (SELECT id FROM gone_conversations)`, nil},
		{`DELETE FROM messages WHERE id IN (SELECT id FROM gone_messages)`, nil},
		{`DELETE FROM conversations WHERE id IN (SELECT id FROM gone_conversations)`, nil},
	})
}

// Delete é o conversations#destroy. Desvio v1: o Chatwoot apaga num job (DeleteObjectJob); aqui é uma
// transação síncrona, como a exclusão de contato e de empresa.
func (c *Conversations) Delete(ctx context.Context, accountID, displayID int32) error {
	return withTx(ctx, c.db, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `CREATE TEMP TABLE gone_conversations ON COMMIT DROP AS SELECT id FROM conversations
			WHERE account_id = $1 AND display_id = $2`, accountID, displayID)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return ErrNotFound
		}
		if _, err := tx.Exec(ctx, `CREATE TEMP TABLE gone_messages ON COMMIT DROP AS SELECT id FROM messages
			WHERE conversation_id IN (SELECT id FROM gone_conversations)`); err != nil {
			return err
		}
		return purgeConversations(ctx, tx)
	})
}
