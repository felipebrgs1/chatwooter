package controllers

import (
	"net/http"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

type Accounts struct {
	Accounts *models.Accounts
}

func (c Accounts) Show(w http.ResponseWriter, r *http.Request) {
	account, err := c.Accounts.ByID(r.Context(), CurrentMembership(r).AccountID)
	if err != nil {
		serverError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.Account(account))
}
