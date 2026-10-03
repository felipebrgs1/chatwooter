package controllers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

// BulkActions porta BulkActionsController#create. Por ora só conversas; o tipo Contact entra com as ações em
// massa de contatos.
type BulkActions struct {
	Conversations *models.Conversations
}

func (b BulkActions) Create(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Type         string                     `json:"type"`
		IDs          []int32                    `json:"ids"`
		Fields       map[string]json.RawMessage `json:"fields"`
		SnoozedUntil int64                      `json:"snoozed_until"`
		Labels       struct {
			Add    []string `json:"add"`
			Remove []string `json:"remove"`
		} `json:"labels"`
	}
	if !decode(w, r, &in) {
		return
	}
	if in.Type != "Conversation" && in.Type != "conversation" {
		views.JSON(w, http.StatusUnprocessableEntity, map[string]bool{"success": false})
		return
	}
	update := models.BulkUpdate{IDs: in.IDs, LabelsAdd: in.Labels.Add, LabelsRemove: in.Labels.Remove}
	// available_params: status nulo é ignorado
	if raw, ok := in.Fields["status"]; ok {
		var status *string
		if err := json.Unmarshal(raw, &status); err != nil {
			views.JSON(w, http.StatusBadRequest, views.Error("Invalid status"))
			return
		}
		update.Status = status
	}
	if in.SnoozedUntil > 0 {
		t := time.Unix(in.SnoozedUntil, 0).UTC()
		update.SnoozedUntil = &t
	}
	if hasKey(in.Fields, "assignee_id") {
		id, ok := optionalID(w, in.Fields["assignee_id"])
		if !ok {
			return
		}
		update.AssigneeID, update.Unassign = id, id == nil
	}
	if hasKey(in.Fields, "team_id") {
		id, ok := optionalID(w, in.Fields["team_id"])
		if !ok {
			return
		}
		// o "None" manda 0; o Chatwoot gravaria team_id = 0, aqui vira nulo como no set_team
		zero := int32(0)
		if id == nil {
			id = &zero
		}
		update.TeamID = id
	}
	m := CurrentMembership(r)
	if err := b.Conversations.BulkUpdate(r.Context(), m.AccountID, CurrentUser(r).ID, m.Administrator(), update); err != nil {
		modelError(w, err)
		return
	}
	w.WriteHeader(http.StatusOK)
}
