package controllers

import (
	"net/http"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

type Profile struct {
	Users *models.Users
}

func (c Profile) Show(w http.ResponseWriter, r *http.Request) {
	p, err := c.Users.Profile(r.Context(), CurrentUser(r).ID)
	if err != nil {
		serverError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.Profile(p))
}
