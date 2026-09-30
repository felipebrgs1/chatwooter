package controllers

import (
	"net/http"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

// Labels é o api/v1/accounts/labels_controller.rb (por ora só o index; LabelPolicy#index? libera admin e agente).
type Labels struct {
	Labels *models.Labels
}

func (c Labels) Index(w http.ResponseWriter, r *http.Request) {
	labels, err := c.Labels.List(r.Context(), CurrentMembership(r).AccountID)
	if err != nil {
		serverError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.Labels(labels))
}
