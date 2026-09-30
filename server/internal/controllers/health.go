// Package controllers traduz HTTP em chamadas aos models e escolhe a view. Não conhece SQL.
package controllers

import (
	"net/http"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

type Health struct {
	System models.System
}

func (c Health) Show(w http.ResponseWriter, r *http.Request) {
	up := c.System.DatabaseUp(r.Context())
	status := http.StatusOK
	if !up {
		status = http.StatusServiceUnavailable
	}
	views.JSON(w, status, views.Health(up))
}
