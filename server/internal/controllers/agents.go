package controllers

import (
	"net/http"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

// Agents porta AgentsController#index (UserPolicy#index? libera a qualquer membro). Convite, edição e
// exclusão entram com a tela Settings → Agents.
type Agents struct{ Agents *models.Agents }

func (a Agents) Index(w http.ResponseWriter, r *http.Request) {
	list, err := a.Agents.List(r.Context(), CurrentMembership(r).AccountID)
	if err != nil {
		serverError(w, err)
		return
	}
	out := make([]views.AgentJSON, 0, len(list))
	for _, agent := range list {
		out = append(out, views.Agent(agent))
	}
	views.JSON(w, http.StatusOK, out)
}
