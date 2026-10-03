package controllers

import (
	"net/http"
	"strconv"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

// AssignableAgents porta AssignableAgentsController#index (sem os agent bots, que só vêm com
// include_ai_assignees). Cada inbox pedida passa pelo InboxPolicy#show?: agente precisa ser membro.
type AssignableAgents struct {
	Agents        *models.Agents
	Conversations *models.Conversations
}

func (a AssignableAgents) Index(w http.ResponseWriter, r *http.Request) {
	var inboxIDs []int32
	for _, raw := range r.URL.Query()["inbox_ids[]"] {
		id, err := strconv.ParseInt(raw, 10, 32)
		if err != nil {
			notFoundJSON(w)
			return
		}
		inboxIDs = append(inboxIDs, int32(id))
	}
	m := CurrentMembership(r)
	list, err := a.Agents.Assignable(r.Context(), m.AccountID, inboxIDs)
	if err != nil {
		modelError(w, err)
		return
	}
	if !m.Administrator() {
		for _, id := range inboxIDs {
			ok, err := a.Conversations.CanAccessInbox(r.Context(), CurrentUser(r).ID, id)
			if err != nil {
				serverError(w, err)
				return
			}
			if !ok {
				unauthorized(w)
				return
			}
		}
	}
	views.JSON(w, http.StatusOK, views.AssignableAgents(list))
}
