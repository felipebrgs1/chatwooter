package models

import (
	"context"
	"time"
)

// hydrate completa a página de conversas com contato, canal, responsável, time e últimas mensagens,
// uma consulta por tipo (nunca uma por conversa).
func (c *Conversations) hydrate(ctx context.Context, accountID, userID int32, items []ConversationItem, links []rowLinks) error {
	if len(items) == 0 {
		return nil
	}
	var contactIDs, assigneeIDs, teamIDs, inboxIDs, convIDs []int64
	for i, it := range items {
		inboxIDs = append(inboxIDs, int64(it.InboxID))
		convIDs = append(convIDs, int64(it.InternalID))
		if l := links[i]; l.contact != nil {
			contactIDs = append(contactIDs, *l.contact)
		}
		if l := links[i]; l.assignee != nil {
			assigneeIDs = append(assigneeIDs, int64(*l.assignee))
		}
		if l := links[i]; l.team != nil {
			teamIDs = append(teamIDs, int64(*l.team))
		}
	}

	contacts, err := c.contactsByID(ctx, contactIDs)
	if err != nil {
		return err
	}
	channels, err := c.channelsByInbox(ctx, inboxIDs)
	if err != nil {
		return err
	}
	agents, err := c.agentsByID(ctx, accountID, assigneeIDs)
	if err != nil {
		return err
	}
	teams, err := c.teamsByID(ctx, teamIDs, userID)
	if err != nil {
		return err
	}
	lastAny, err := loadMessages(ctx, c.db, `m.id IN (SELECT DISTINCT ON (conversation_id) id FROM messages
		WHERE conversation_id = ANY($1) ORDER BY conversation_id, created_at DESC, id DESC)`, convIDs)
	if err != nil {
		return err
	}
	lastReal, err := loadMessages(ctx, c.db, `m.id IN (SELECT DISTINCT ON (conversation_id) id FROM messages
		WHERE conversation_id = ANY($1) AND message_type <> 2 ORDER BY conversation_id, id DESC)`, convIDs)
	if err != nil {
		return err
	}
	lastAnyBy, lastRealBy := map[int32]*Message{}, map[int32]*Message{}
	for i := range lastAny {
		lastAnyBy[lastAny[i].ConversationID] = &lastAny[i]
	}
	for i := range lastReal {
		lastRealBy[lastReal[i].ConversationID] = &lastReal[i]
	}

	for i := range items {
		it, l := &items[i], links[i]
		if l.contact != nil {
			it.Contact = contacts[*l.contact]
		}
		it.Channel = channels[int64(it.InboxID)]
		if l.assignee != nil {
			if a, ok := agents[int64(*l.assignee)]; ok {
				it.Assignee = &a
			}
		}
		if l.team != nil {
			if tm, ok := teams[int64(*l.team)]; ok {
				it.Team = &tm
			}
		}
		it.LastMessage, it.LastNonActivity = lastAnyBy[it.ID], lastRealBy[it.ID]
	}
	return nil
}

func (c *Conversations) contactsByID(ctx context.Context, ids []int64) (map[int64]Contact, error) {
	out := map[int64]Contact{}
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := c.db.Query(ctx, `SELECT id, name, COALESCE(email, ''), COALESCE(phone_number, ''), COALESCE(identifier, ''), blocked,
		additional_attributes, custom_attributes, created_at, last_activity_at FROM contacts WHERE id = ANY($1)`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var ct Contact
		var created time.Time
		var additional, custom []byte
		if err := rows.Scan(&ct.ID, &ct.Name, &ct.Email, &ct.PhoneNumber, &ct.Identifier, &ct.Blocked, &additional, &custom, &created, &ct.LastActivityAt); err != nil {
			return nil, err
		}
		ct.CreatedAt = created
		ct.AdditionalAttributes, ct.CustomAttributes = orEmptyObject(additional), orEmptyObject(custom)
		out[int64(ct.ID)] = ct
	}
	return out, rows.Err()
}

func (c *Conversations) channelsByInbox(ctx context.Context, ids []int64) (map[int64]string, error) {
	out := map[int64]string{}
	rows, err := c.db.Query(ctx, `SELECT id, COALESCE(channel_type, '') FROM inboxes WHERE id = ANY($1)`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id int32
		var channel string
		if err := rows.Scan(&id, &channel); err != nil {
			return nil, err
		}
		out[int64(id)] = channel
	}
	return out, rows.Err()
}

func (c *Conversations) agentsByID(ctx context.Context, accountID int32, ids []int64) (map[int64]Agent, error) {
	return agentsByID(ctx, c.db, accountID, ids)
}

// agentsByID carrega usuários no formato _agent.json.jbuilder, com o papel e a disponibilidade na conta.
func agentsByID(ctx context.Context, db DB, accountID int32, ids []int64) (map[int64]Agent, error) {
	out := map[int64]Agent{}
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := db.Query(ctx, `SELECT u.id, COALESCE(u.email, ''), u.provider, u.name, COALESCE(u.display_name, ''),
		u.confirmed_at IS NOT NULL, COALESCE(au.role, 0), au.availability, au.auto_offline
		FROM users u JOIN account_users au ON au.user_id = u.id AND au.account_id = $2 WHERE u.id = ANY($1)`, ids, accountID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var a Agent
		var display string
		var role, availability int32
		if err := rows.Scan(&a.ID, &a.Email, &a.Provider, &a.Name, &display, &a.Confirmed, &role, &availability, &a.AutoOffline); err != nil {
			return nil, err
		}
		a.AccountID = accountID
		a.AvailableName = a.Name
		if display != "" {
			a.AvailableName = display
		}
		a.Role, a.AvailabilityStatus = "agent", availabilityName(availability)
		if role == 1 {
			a.Role = "administrator"
		}
		out[int64(a.ID)] = a
	}
	return out, rows.Err()
}

func (c *Conversations) teamsByID(ctx context.Context, ids []int64, userID int32) (map[int64]Team, error) {
	out := map[int64]Team{}
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := c.db.Query(ctx, `SELECT t.id, t.account_id, t.name, COALESCE(t.description, ''), COALESCE(t.allow_auto_assign, true),
		COALESCE(t.icon, ''), COALESCE(t.icon_color, ''), EXISTS (SELECT 1 FROM team_members tm WHERE tm.team_id = t.id AND tm.user_id = $2)
		FROM teams t WHERE t.id = ANY($1)`, ids, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var tm Team
		var id, account int64
		if err := rows.Scan(&id, &account, &tm.Name, &tm.Description, &tm.AllowAutoAssign, &tm.Icon, &tm.IconColor, &tm.IsMember); err != nil {
			return nil, err
		}
		tm.ID, tm.AccountID = int32(id), int32(account) //nolint:gosec // ids integer
		out[id] = tm
	}
	return out, rows.Err()
}
