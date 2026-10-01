package models

import (
	"context"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

const messagesPageSize = 20

// internalID resolve o display_id para o id interno, sempre dentro da conta.
func (c *Conversations) internalID(ctx context.Context, accountID, displayID int32) (id, inboxID int32, err error) {
	err = c.db.QueryRow(ctx, `SELECT id, inbox_id FROM conversations WHERE account_id = $1 AND display_id = $2`,
		accountID, displayID).Scan(&id, &inboxID)
	return id, inboxID, notFound(err)
}

// Messages devolve até 20 mensagens em ordem crescente: as mais recentes ou, com before, as anteriores a esse id.
func (c *Conversations) Messages(ctx context.Context, accountID, displayID, before int32) ([]Message, error) {
	id, _, err := c.internalID(ctx, accountID, displayID)
	if err != nil {
		return nil, err
	}
	return loadMessages(ctx, c.db, `m.id IN (SELECT id FROM messages WHERE conversation_id = $1 AND ($2::int = 0 OR id < $2)
		ORDER BY id DESC LIMIT `+strconv.Itoa(messagesPageSize)+`)`, id, before)
}

type NewMessage struct {
	SenderID int32
	Content  string
	Private  bool
	EchoID   string
}

// CreateMessage grava a resposta (ou nota privada) de um agente. A entrega ao canal é um job à parte.
func (c *Conversations) CreateMessage(ctx context.Context, accountID, displayID int32, in NewMessage) (Message, error) {
	content := strings.TrimSpace(in.Content)
	if content == "" {
		return Message{}, ErrInvalid
	}
	convID, inboxID, err := c.internalID(ctx, accountID, displayID)
	if err != nil {
		return Message{}, err
	}

	var id int32
	err = withTx(ctx, c.db, func(tx pgx.Tx) error {
		if err := tx.QueryRow(ctx, `INSERT INTO messages (conversation_id, account_id, inbox_id, message_type, content, private,
				sender_type, sender_id, status, created_at, updated_at)
			VALUES ($1, $2, $3, 1, $4, $5, 'User', $6, 0, now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc') RETURNING id`,
			convID, accountID, inboxID, content, in.Private, in.SenderID).Scan(&id); err != nil {
			return err
		}
		// Resposta pública do agente: a conversa deixa de aguardar e registra a primeira resposta.
		_, err := tx.Exec(ctx, `UPDATE conversations SET last_activity_at = now() AT TIME ZONE 'utc', updated_at = now() AT TIME ZONE 'utc',
			waiting_since = CASE WHEN $2 THEN waiting_since ELSE NULL END,
			first_reply_created_at = CASE WHEN $2 THEN first_reply_created_at ELSE COALESCE(first_reply_created_at, now() AT TIME ZONE 'utc') END
			WHERE id = $1`, convID, in.Private)
		return err
	})
	if err != nil {
		return Message{}, err
	}
	msgs, err := loadMessages(ctx, c.db, `m.id = $1`, id)
	if err != nil || len(msgs) == 0 {
		return Message{}, err
	}
	msgs[0].EchoID = in.EchoID
	return msgs[0], nil
}

type StatusChange struct {
	ConversationID int32
	Status         string
	SnoozedUntil   *time.Time
}

func (c *Conversations) ToggleStatus(ctx context.Context, accountID, displayID int32, status string, snoozedUntil *time.Time) (StatusChange, error) {
	value, ok := statusValues[status]
	if !ok {
		return StatusChange{}, ErrInvalid
	}
	if status != "snoozed" {
		snoozedUntil = nil
	}
	tag, err := c.db.Exec(ctx, `UPDATE conversations SET status = $3, snoozed_until = $4, status_changed_at = now() AT TIME ZONE 'utc',
		updated_at = now() AT TIME ZONE 'utc' WHERE account_id = $1 AND display_id = $2`, accountID, displayID, value, snoozedUntil)
	if err != nil {
		return StatusChange{}, err
	}
	if tag.RowsAffected() == 0 {
		return StatusChange{}, ErrNotFound
	}
	return StatusChange{ConversationID: displayID, Status: status, SnoozedUntil: snoozedUntil}, nil
}

// AssignAgent atribui a conversa a um agente da conta (nil desatribui) e devolve o agente.
func (c *Conversations) AssignAgent(ctx context.Context, accountID, displayID int32, userID *int32) (*Agent, error) {
	if _, _, err := c.internalID(ctx, accountID, displayID); err != nil {
		return nil, err
	}
	var agent *Agent
	if userID != nil {
		agents, err := c.agentsByID(ctx, accountID, []int64{int64(*userID)})
		if err != nil {
			return nil, err
		}
		a, ok := agents[int64(*userID)]
		if !ok {
			return nil, ErrInvalid
		}
		agent = &a
	}
	_, err := c.db.Exec(ctx, `UPDATE conversations SET assignee_id = $3, updated_at = now() AT TIME ZONE 'utc'
		WHERE account_id = $1 AND display_id = $2`, accountID, displayID, userID)
	return agent, err
}

// AssignTeam é o set_team: id que não é positivo (o "None" do painel manda 0) tira o time.
func (c *Conversations) AssignTeam(ctx context.Context, accountID, displayID int32, teamID *int32) (*Team, error) {
	if _, _, err := c.internalID(ctx, accountID, displayID); err != nil {
		return nil, err
	}
	if teamID != nil && *teamID <= 0 {
		teamID = nil
	}
	var team *Team
	if teamID != nil {
		var owner int64
		if err := c.db.QueryRow(ctx, `SELECT account_id FROM teams WHERE id = $1`, *teamID).Scan(&owner); err != nil || int32(owner) != accountID { //nolint:gosec // ids integer
			return nil, ErrInvalid
		}
		teams, err := c.teamsByID(ctx, []int64{int64(*teamID)}, 0)
		if err != nil {
			return nil, err
		}
		t := teams[int64(*teamID)]
		team = &t
	}
	_, err := c.db.Exec(ctx, `UPDATE conversations SET team_id = $3, updated_at = now() AT TIME ZONE 'utc'
		WHERE account_id = $1 AND display_id = $2`, accountID, displayID, teamID)
	return team, err
}

// MarkSeen zera o contador de não lidas do agente.
func (c *Conversations) MarkSeen(ctx context.Context, accountID, displayID int32) error {
	return c.touch(ctx, accountID, displayID, `agent_last_seen_at = now() AT TIME ZONE 'utc'`)
}

// MarkUnread devolve o agente a um segundo antes da última mensagem recebida ("Mark as unread").
func (c *Conversations) MarkUnread(ctx context.Context, accountID, displayID int32) error {
	return c.touch(ctx, accountID, displayID, `agent_last_seen_at = (SELECT max(m.created_at) - interval '1 second' FROM messages m
		WHERE m.conversation_id = conversations.id AND m.message_type = 0),
		assignee_last_seen_at = (SELECT max(m.created_at) - interval '1 second' FROM messages m
		WHERE m.conversation_id = conversations.id AND m.message_type = 0)`)
}

func (c *Conversations) touch(ctx context.Context, accountID, displayID int32, set string) error {
	tag, err := c.db.Exec(ctx, `UPDATE conversations SET `+set+` WHERE account_id = $1 AND display_id = $2`, accountID, displayID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func withTx(ctx context.Context, db DB, fn func(pgx.Tx) error) error {
	tx, err := db.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
