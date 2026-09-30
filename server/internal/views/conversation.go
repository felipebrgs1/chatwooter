package views

import (
	"encoding/json"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

// ConversationJSON espelha api/v1/conversations/partials/_conversation.json.jbuilder.
type ConversationJSON struct {
	Meta                ConversationMeta `json:"meta"`
	ID                  int32            `json:"id"`
	Messages            []MessageJSON    `json:"messages"`
	AccountID           int32            `json:"account_id"`
	UUID                string           `json:"uuid"`
	AdditionalAttrs     json.RawMessage  `json:"additional_attributes"`
	AgentLastSeenAt     int64            `json:"agent_last_seen_at"`
	AssigneeLastSeenAt  int64            `json:"assignee_last_seen_at"`
	CanReply            bool             `json:"can_reply"`
	ContactLastSeenAt   int64            `json:"contact_last_seen_at"`
	CustomAttrs         json.RawMessage  `json:"custom_attributes"`
	InboxID             int32            `json:"inbox_id"`
	Labels              []string         `json:"labels"`
	Muted               bool             `json:"muted"`
	SnoozedUntil        *string          `json:"snoozed_until"`
	Status              string           `json:"status"`
	CreatedAt           int64            `json:"created_at"`
	UpdatedAt           float64          `json:"updated_at"`
	Timestamp           int64            `json:"timestamp"`
	FirstReplyCreatedAt int64            `json:"first_reply_created_at"`
	UnreadCount         int              `json:"unread_count"`
	LastNonActivity     *MessageJSON     `json:"last_non_activity_message"`
	LastActivityAt      int64            `json:"last_activity_at"`
	Priority            *string          `json:"priority"`
	WaitingSince        int64            `json:"waiting_since"`
	SLAPolicyID         *int64           `json:"sla_policy_id"`
}

type ConversationMeta struct {
	Sender       ContactJSON `json:"sender"`
	Channel      *string     `json:"channel"`
	Assignee     *AgentJSON  `json:"assignee,omitempty"`
	AssigneeType string      `json:"assignee_type,omitempty"`
	Team         *TeamJSON   `json:"team,omitempty"`
	HmacVerified *bool       `json:"hmac_verified"`
}

func epoch(t *time.Time) int64 {
	if t == nil {
		return 0
	}
	return t.Unix()
}

func Conversation(c models.ConversationItem) ConversationJSON {
	out := ConversationJSON{
		Meta:               ConversationMeta{Sender: Contact(c.Contact), Channel: nilIfEmpty(c.Channel)},
		ID:                 c.ID,
		Messages:           []MessageJSON{},
		AccountID:          c.AccountID,
		UUID:               c.UUID,
		AdditionalAttrs:    c.AdditionalAttrs,
		AgentLastSeenAt:    epoch(c.AgentLastSeenAt),
		AssigneeLastSeenAt: epoch(c.AssigneeLastSeenAt),
		// TODO(WhatsApp): can_reply depende da janela de 24h do canal.
		CanReply:            true,
		ContactLastSeenAt:   epoch(c.ContactLastSeenAt),
		CustomAttrs:         c.CustomAttrs,
		InboxID:             c.InboxID,
		Labels:              c.Labels,
		SnoozedUntil:        railsTimePtr(c.SnoozedUntil),
		Status:              c.Status,
		CreatedAt:           c.CreatedAt.Unix(),
		UpdatedAt:           float64(c.UpdatedAt.UnixMicro()) / 1e6,
		Timestamp:           c.LastActivityAt.Unix(),
		FirstReplyCreatedAt: epoch(c.FirstReplyCreatedAt),
		UnreadCount:         c.UnreadCount,
		LastNonActivity:     messagePtr(c.LastNonActivity),
		LastActivityAt:      c.LastActivityAt.Unix(),
		Priority:            c.Priority,
		WaitingSince:        epoch(c.WaitingSince),
		SLAPolicyID:         c.SLAPolicyID,
	}
	if c.LastMessage != nil {
		out.Messages = []MessageJSON{Message(*c.LastMessage)}
	}
	if c.Assignee != nil {
		a := Agent(*c.Assignee)
		out.Meta.Assignee, out.Meta.AssigneeType = &a, "User"
	}
	if c.Team != nil {
		tm := Team(*c.Team)
		out.Meta.Team = &tm
	}
	return out
}

type countsJSON struct {
	MineCount       int `json:"mine_count"`
	AssignedCount   int `json:"assigned_count"`
	UnassignedCount int `json:"unassigned_count"`
	AllCount        int `json:"all_count"`
}

func counts(c models.ConversationCounts) countsJSON {
	return countsJSON{MineCount: c.Mine, AssignedCount: c.Assigned, UnassignedCount: c.Unassigned, AllCount: c.All}
}

// ConversationsIndex espelha accounts/conversations/index.json.jbuilder.
func ConversationsIndex(items []models.ConversationItem, c models.ConversationCounts) map[string]any {
	payload := make([]ConversationJSON, 0, len(items))
	for _, it := range items {
		payload = append(payload, Conversation(it))
	}
	return map[string]any{"data": map[string]any{"meta": counts(c), "payload": payload}}
}

// ConversationsMeta espelha accounts/conversations/meta.json.jbuilder.
func ConversationsMeta(c models.ConversationCounts) map[string]any {
	return map[string]any{"meta": counts(c)}
}

// ToggleStatus espelha accounts/conversations/toggle_status.json.jbuilder.
func ToggleStatus(s models.StatusChange) map[string]any {
	return map[string]any{
		"meta": map[string]any{},
		"payload": map[string]any{
			"success": true, "conversation_id": s.ConversationID, "current_status": s.Status, "snoozed_until": railsTimePtr(s.SnoozedUntil),
		},
	}
}
