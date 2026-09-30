package models

import (
	"context"
	"fmt"
)

// contactConversationsLimit é o RESULTS_PER_PAGE do contacts/conversations_controller.rb.
const contactConversationsLimit = 25

// ForContact é o contacts/conversations#index: as 25 conversas mais recentes do contato, filtradas pelo
// PermissionFilterService (onlyInboxesOfUser = agente só vê as inboxes de que é membro; nil = administrador).
func (c *Conversations) ForContact(ctx context.Context, accountID, contactID, userID int32, onlyInboxesOfUser *int32) ([]ConversationItem, error) {
	if err := (&Contacts{db: c.db}).exists(ctx, accountID, contactID); err != nil {
		return nil, err
	}
	where := "c.account_id = $1 AND c.contact_id = $2"
	args := []any{accountID, contactID}
	if onlyInboxesOfUser != nil {
		args = append(args, *onlyInboxesOfUser)
		where += " AND c.inbox_id IN (SELECT im.inbox_id FROM inbox_members im JOIN inboxes i ON i.id = im.inbox_id WHERE im.user_id = $3 AND i.account_id = $1)"
	}
	rows, err := c.db.Query(ctx, fmt.Sprintf(`SELECT %s FROM conversations c WHERE %s ORDER BY c.last_activity_at DESC, c.id DESC LIMIT %d`,
		conversationColumns, where, contactConversationsLimit), args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []ConversationItem{}
	var links []rowLinks
	for rows.Next() {
		it, assignee, team, contact, err := scanConversation(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, it)
		links = append(links, rowLinks{assignee, team, contact})
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	rows.Close()
	return items, c.hydrate(ctx, accountID, userID, items, links)
}
