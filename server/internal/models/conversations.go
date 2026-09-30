package models

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
)

// Conversations é o ConversationFinder do Chatwoot: lista, contadores e leitura de uma conversa.
type Conversations struct {
	db DB
}

// DB é o que o model precisa do banco: consultas e transações (um *pgxpool.Pool serve).
type DB interface {
	sqlc.DBTX
	Begin(ctx context.Context) (pgx.Tx, error)
}

func NewConversations(db DB) *Conversations { return &Conversations{db: db} }

var statusNames = map[int32]string{0: "open", 1: "resolved", 2: "pending", 3: "snoozed"}

var statusValues = map[string]int32{"open": 0, "resolved": 1, "pending": 2, "snoozed": 3}

var priorityNames = map[int32]string{0: "low", 1: "medium", 2: "high", 3: "urgent"}

const conversationColumns = `c.id, c.display_id, c.account_id, c.uuid::text, c.inbox_id, c.status, c.priority, c.snoozed_until,
	c.additional_attributes, c.custom_attributes, c.agent_last_seen_at, c.assignee_last_seen_at, c.contact_last_seen_at,
	c.first_reply_created_at, c.created_at, c.updated_at, c.last_activity_at, c.waiting_since, c.sla_policy_id,
	COALESCE(c.cached_label_list, ''), c.assignee_id, c.team_id, c.contact_id,
	LEAST((SELECT count(*) FROM messages m WHERE m.conversation_id = c.id AND m.message_type = 0
		AND (c.agent_last_seen_at IS NULL OR m.created_at > c.agent_last_seen_at)), 10)`

func scanConversation(row pgx.Row) (ConversationItem, *int32, *int32, *int64, error) {
	var (
		it                 ConversationItem
		status             int32
		priority           *int32
		labels             string
		assigneeID, teamID *int32
		contactID          *int64
		unread             int64
	)
	err := row.Scan(&it.InternalID, &it.ID, &it.AccountID, &it.UUID, &it.InboxID, &status, &priority, &it.SnoozedUntil,
		&it.AdditionalAttrs, &it.CustomAttrs, &it.AgentLastSeenAt, &it.AssigneeLastSeenAt, &it.ContactLastSeenAt,
		&it.FirstReplyCreatedAt, &it.CreatedAt, &it.UpdatedAt, &it.LastActivityAt, &it.WaitingSince, &it.SLAPolicyID,
		&labels, &assigneeID, &teamID, &contactID, &unread)
	if err != nil {
		return it, nil, nil, nil, err
	}
	it.Status = statusNames[status]
	if priority != nil {
		name := priorityNames[*priority]
		it.Priority = &name
	}
	it.UnreadCount = int(unread)
	it.Labels = splitLabels(labels)
	return it, assigneeID, teamID, contactID, nil
}

func splitLabels(cached string) []string {
	out := []string{}
	for _, l := range strings.Split(cached, ",") {
		if l = strings.TrimSpace(l); l != "" {
			out = append(out, l)
		}
	}
	return out
}

// where monta o filtro comum (sem o de responsável, que não entra nos contadores) e os argumentos.
func (f ConversationFilter) where(accountID int32) (string, []any) {
	args := []any{accountID}
	arg := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", len(args))
	}
	conds := []string{"c.account_id = $1"}

	status := f.Status
	if status == "" {
		status = "open"
	}
	if v, ok := statusValues[status]; ok {
		conds = append(conds, "c.status = "+arg(v))
	}
	if f.OnlyInboxesOfUser != 0 {
		conds = append(conds, "c.inbox_id IN (SELECT inbox_id FROM inbox_members WHERE user_id = "+arg(f.OnlyInboxesOfUser)+")")
	}
	if f.InboxID != 0 {
		conds = append(conds, "c.inbox_id = "+arg(f.InboxID))
	}
	if f.TeamID != 0 {
		conds = append(conds, "c.team_id = "+arg(f.TeamID))
	}
	if f.Label != "" {
		conds = append(conds, `c.id IN (SELECT tg.taggable_id FROM taggings tg JOIN tags t ON t.id = tg.tag_id
			WHERE tg.taggable_type = 'Conversation' AND tg.context = 'labels' AND lower(t.name) = lower(`+arg(f.Label)+`))`)
	}
	switch f.ConversationType {
	case "mention":
		conds = append(conds, "c.id IN (SELECT conversation_id FROM mentions WHERE user_id = "+arg(f.UserID)+")")
	case "participating":
		conds = append(conds, "c.id IN (SELECT conversation_id FROM conversation_participants WHERE user_id = "+arg(f.UserID)+")")
	case "unattended":
		conds = append(conds, "(c.first_reply_created_at IS NULL OR c.waiting_since IS NOT NULL)")
	}
	return strings.Join(conds, " AND "), args
}

func assigneeCondition(f ConversationFilter, args []any) (string, []any) {
	switch f.AssigneeType {
	case "me":
		args = append(args, f.UserID)
		return fmt.Sprintf(" AND c.assignee_id = $%d", len(args)), args
	case "assigned":
		return " AND c.assignee_id IS NOT NULL", args
	case "unassigned":
		return " AND c.assignee_id IS NULL AND c.assignee_agent_bot_id IS NULL", args
	}
	return "", args
}

// Conversations::SortService do Chatwoot.
func orderBy(sortBy string) string {
	switch sortBy {
	case "last_activity_at_asc":
		return "c.last_activity_at ASC, c.id ASC"
	case "created_at_asc":
		return "c.created_at ASC, c.id ASC"
	case "created_at_desc":
		return "c.created_at DESC, c.id DESC"
	case "priority_desc":
		return "c.priority DESC NULLS LAST, c.last_activity_at DESC"
	case "priority_asc":
		return "c.priority ASC NULLS LAST, c.last_activity_at DESC"
	case "priority_desc_created_at_asc":
		return "c.priority DESC NULLS LAST, c.created_at ASC"
	case "waiting_since_asc":
		return "(c.waiting_since IS NULL) ASC, c.waiting_since ASC, c.created_at ASC"
	case "waiting_since_desc":
		return "(c.waiting_since IS NULL) ASC, c.waiting_since DESC, c.created_at ASC"
	case "unread":
		return "LEAST((SELECT count(*) FROM messages m WHERE m.conversation_id = c.id AND m.message_type = 0 AND (c.agent_last_seen_at IS NULL OR m.created_at > c.agent_last_seen_at)), 10) DESC, c.last_activity_at DESC"
	}
	return "c.last_activity_at DESC, c.id DESC"
}

// List devolve uma página de conversas e os contadores das abas (mesmo filtro, sem o de responsável).
func (c *Conversations) List(ctx context.Context, accountID int32, f ConversationFilter) ([]ConversationItem, ConversationCounts, error) {
	where, args := f.where(accountID)

	var counts ConversationCounts
	err := c.db.QueryRow(ctx, fmt.Sprintf(`SELECT
		count(*) FILTER (WHERE c.assignee_id = $%d), count(*) FILTER (WHERE c.assignee_id IS NOT NULL),
		count(*) FILTER (WHERE c.assignee_id IS NULL AND c.assignee_agent_bot_id IS NULL), count(*)
		FROM conversations c WHERE %s`, len(args)+1, where), append(append([]any{}, args...), f.UserID)...).
		Scan(&counts.Mine, &counts.Assigned, &counts.Unassigned, &counts.All)
	if err != nil {
		return nil, counts, err
	}

	extra, listArgs := assigneeCondition(f, append([]any{}, args...))
	page := max(f.Page, 1)
	listArgs = append(listArgs, conversationsPageSize, (page-1)*conversationsPageSize)
	rows, err := c.db.Query(ctx, fmt.Sprintf(`SELECT %s FROM conversations c WHERE %s%s ORDER BY %s LIMIT $%d OFFSET $%d`,
		conversationColumns, where, extra, orderBy(f.SortBy), len(listArgs)-1, len(listArgs)), listArgs...)
	if err != nil {
		return nil, counts, err
	}
	defer rows.Close()

	var items []ConversationItem
	var links []rowLinks
	for rows.Next() {
		it, assignee, team, contact, err := scanConversation(rows)
		if err != nil {
			return nil, counts, err
		}
		items = append(items, it)
		links = append(links, rowLinks{assignee, team, contact})
	}
	if err := rows.Err(); err != nil {
		return nil, counts, err
	}
	rows.Close()

	if err := c.hydrate(ctx, accountID, f.UserID, items, links); err != nil {
		return nil, counts, err
	}
	return items, counts, nil
}

// Get devolve uma conversa pelo display_id (o "#123"), sempre dentro da conta.
func (c *Conversations) Get(ctx context.Context, accountID, displayID int32) (ConversationItem, error) {
	row := c.db.QueryRow(ctx, fmt.Sprintf(`SELECT %s FROM conversations c WHERE c.account_id = $1 AND c.display_id = $2`, conversationColumns),
		accountID, displayID)
	it, assignee, team, contact, err := scanConversation(row)
	if err != nil {
		return ConversationItem{}, notFound(err)
	}
	items := []ConversationItem{it}
	if err := c.hydrate(ctx, accountID, 0, items, []rowLinks{{assignee, team, contact}}); err != nil {
		return ConversationItem{}, err
	}
	return items[0], nil
}

type rowLinks struct {
	assignee, team *int32
	contact        *int64
}

// CanAccessInbox diz se o usuário é agente da inbox (administradores não precisam: veem todas).
func (c *Conversations) CanAccessInbox(ctx context.Context, userID, inboxID int32) (bool, error) {
	var ok bool
	err := c.db.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM inbox_members WHERE user_id = $1 AND inbox_id = $2)`, userID, inboxID).Scan(&ok)
	return ok, err
}
