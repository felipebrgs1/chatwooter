package controllers

import (
	"net/http"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

// Teams é o api/v1/accounts/teams_controller.rb (por ora só o index).
type Teams struct {
	Teams *models.Teams
}

func (c Teams) Index(w http.ResponseWriter, r *http.Request) {
	teams, err := c.Teams.List(r.Context(), CurrentMembership(r).AccountID, CurrentUser(r).ID)
	if err != nil {
		serverError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.Teams(teams))
}
