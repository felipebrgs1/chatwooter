// Package router liga URLs a controllers. Toda rota da API é declarada aqui.
package router

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"github.com/felipeborgaco/chatwooter/server/internal/controllers"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

type Deps struct {
	System models.System
}

func New(d Deps) http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.RequestID, middleware.Recoverer)
	r.Get("/health", controllers.Health{System: d.System}.Show)
	return r
}
