package controllers

import (
	"net/http"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

// Inboxes é o api/v1/accounts/inboxes_controller.rb (por ora só o index).
type Inboxes struct {
	Inboxes *models.Inboxes
}

func (c Inboxes) Index(w http.ResponseWriter, r *http.Request) {
	// InboxPolicy::Scope → User#assigned_inboxes: agente só vê as inboxes de que é membro
	var memberID *int32
	if !CurrentMembership(r).Administrator() {
		id := CurrentUser(r).ID
		memberID = &id
	}
	inboxes, err := c.Inboxes.List(r.Context(), CurrentMembership(r).AccountID, memberID)
	if err != nil {
		serverError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.Inboxes(inboxes))
}
