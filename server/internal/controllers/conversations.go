package controllers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

// Conversations serve /api/v1/accounts/{account_id}/conversations (ConversationsController do Chatwoot).
type Conversations struct {
	Conversations *models.Conversations
}

// filter lê os parâmetros da lista. Agentes só enxergam as inboxes de que são membros.
func (c Conversations) filter(r *http.Request) models.ConversationFilter {
	q := r.URL.Query()
	f := models.ConversationFilter{
		UserID:           CurrentUser(r).ID,
		Status:           q.Get("status"),
		AssigneeType:     q.Get("assignee_type"),
		InboxID:          intParam(q.Get("inbox_id")),
		TeamID:           intParam(q.Get("team_id")),
		Label:            q.Get("label"),
		ConversationType: q.Get("conversation_type"),
		SortBy:           q.Get("sort_by"),
		Page:             int(intParam(q.Get("page"))),
	}
	if labels := q["labels[]"]; len(labels) > 0 && f.Label == "" {
		f.Label = labels[0]
	}
	if !CurrentMembership(r).Administrator() {
		f.OnlyInboxesOfUser = f.UserID
	}
	return f
}

func intParam(s string) int32 {
	n, err := strconv.ParseInt(s, 10, 32)
	if err != nil || n < 0 {
		return 0
	}
	return int32(n)
}

func (c Conversations) Index(w http.ResponseWriter, r *http.Request) {
	items, counts, err := c.Conversations.List(r.Context(), CurrentMembership(r).AccountID, c.filter(r))
	if err != nil {
		serverError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.ConversationsIndex(items, counts))
}

func (c Conversations) Meta(w http.ResponseWriter, r *http.Request) {
	f := c.filter(r)
	f.Page = 1
	_, counts, err := c.Conversations.List(r.Context(), CurrentMembership(r).AccountID, f)
	if err != nil {
		serverError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.ConversationsMeta(counts))
}

// load resolve {conversation_id} (display_id) dentro da conta e confere o acesso à inbox.
func (c Conversations) load(w http.ResponseWriter, r *http.Request) (models.ConversationItem, bool) {
	id, err := strconv.ParseInt(chi.URLParam(r, "conversation_id"), 10, 32)
	if err != nil {
		notFoundJSON(w)
		return models.ConversationItem{}, false
	}
	m := CurrentMembership(r)
	item, err := c.Conversations.Get(r.Context(), m.AccountID, int32(id))
	switch {
	case errors.Is(err, models.ErrNotFound):
		notFoundJSON(w)
		return item, false
	case err != nil:
		serverError(w, err)
		return item, false
	}
	if !m.Administrator() {
		ok, err := c.Conversations.CanAccessInbox(r.Context(), CurrentUser(r).ID, item.InboxID)
		if err != nil {
			serverError(w, err)
			return item, false
		}
		if !ok {
			unauthorized(w)
			return item, false
		}
	}
	return item, true
}

func (c Conversations) Show(w http.ResponseWriter, r *http.Request) {
	if item, ok := c.load(w, r); ok {
		views.JSON(w, http.StatusOK, views.Conversation(item))
	}
}

func (c Conversations) ToggleStatus(w http.ResponseWriter, r *http.Request) {
	item, ok := c.load(w, r)
	if !ok {
		return
	}
	var in struct {
		Status       string `json:"status"`
		SnoozedUntil int64  `json:"snoozed_until"`
	}
	if !decode(w, r, &in) {
		return
	}
	status := in.Status
	if status == "" { // sem corpo, o Chatwoot alterna entre aberta e resolvida
		status = "resolved"
		if item.Status == "resolved" {
			status = "open"
		}
	}
	var until *time.Time
	if in.SnoozedUntil > 0 {
		t := time.Unix(in.SnoozedUntil, 0).UTC()
		until = &t
	}
	change, err := c.Conversations.ToggleStatus(r.Context(), item.AccountID, item.ID, status, until)
	if err != nil {
		modelError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.ToggleStatus(change))
}

func (c Conversations) Assign(w http.ResponseWriter, r *http.Request) {
	item, ok := c.load(w, r)
	if !ok {
		return
	}
	var in map[string]json.RawMessage
	if !decode(w, r, &in) {
		return
	}
	switch {
	case hasKey(in, "assignee_id"):
		id, ok := optionalID(w, in["assignee_id"])
		if !ok {
			return
		}
		agent, err := c.Conversations.AssignAgent(r.Context(), item.AccountID, item.ID, id)
		if err != nil {
			modelError(w, err)
			return
		}
		if agent == nil {
			views.JSON(w, http.StatusOK, nil)
			return
		}
		views.JSON(w, http.StatusOK, views.Agent(*agent))
	case hasKey(in, "team_id"):
		id, ok := optionalID(w, in["team_id"])
		if !ok {
			return
		}
		team, err := c.Conversations.AssignTeam(r.Context(), item.AccountID, item.ID, id)
		if err != nil {
			modelError(w, err)
			return
		}
		if team == nil {
			views.JSON(w, http.StatusOK, nil)
			return
		}
		views.JSON(w, http.StatusOK, views.Team(*team))
	default:
		views.JSON(w, http.StatusOK, nil)
	}
}

func (c Conversations) UpdateLastSeen(w http.ResponseWriter, r *http.Request) {
	c.seen(w, r, c.Conversations.MarkSeen)
}

func (c Conversations) Unread(w http.ResponseWriter, r *http.Request) {
	c.seen(w, r, c.Conversations.MarkUnread)
}

type seenFunc func(ctx context.Context, accountID, displayID int32) error

func (c Conversations) seen(w http.ResponseWriter, r *http.Request, fn seenFunc) {
	item, ok := c.load(w, r)
	if !ok {
		return
	}
	if err := fn(r.Context(), item.AccountID, item.ID); err != nil {
		modelError(w, err)
		return
	}
	updated, err := c.Conversations.Get(r.Context(), item.AccountID, item.ID)
	if err != nil {
		serverError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.Conversation(updated))
}

func hasKey(m map[string]json.RawMessage, key string) bool {
	_, ok := m[key]
	return ok
}

// optionalID lê um id ou null (desatribuir).
func optionalID(w http.ResponseWriter, raw json.RawMessage) (*int32, bool) {
	if string(raw) == "null" {
		return nil, true
	}
	var id int32
	if err := json.Unmarshal(raw, &id); err != nil {
		views.JSON(w, http.StatusBadRequest, views.Error("Invalid id"))
		return nil, false
	}
	return &id, true
}
