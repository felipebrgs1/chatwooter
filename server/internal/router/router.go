// Package router liga URLs a controllers. Toda rota da API é declarada aqui.
package router

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"github.com/felipeborgaco/chatwooter/server/internal/controllers"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

type Deps struct {
	System       models.System
	Users        *models.Users
	Sessions     *models.Sessions
	Accounts     *models.Accounts
	SessionTTL   time.Duration
	CookieSecure bool
}

func New(d Deps) http.Handler {
	authn := controllers.Authenticate{Users: d.Users, Sessions: d.Sessions}
	scope := controllers.AccountScope{Users: d.Users, Accounts: d.Accounts}
	auth := controllers.Auth{Users: d.Users, Sessions: d.Sessions, SessionTTL: d.SessionTTL, CookieSecure: d.CookieSecure}

	r := chi.NewRouter()
	r.Use(middleware.RequestID, middleware.Recoverer)

	r.Get("/health", controllers.Health{System: d.System}.Show)

	r.Post("/auth/sign_in", auth.SignIn)
	r.Delete("/auth/sign_out", auth.SignOut)

	r.Route("/api/v1", func(r chi.Router) {
		r.Use(authn.Require)
		r.Get("/profile", controllers.Profile{Users: d.Users}.Show)

		r.Route("/accounts/{account_id}", func(r chi.Router) {
			r.Use(scope.Require)
			r.Get("/", controllers.Accounts{Accounts: d.Accounts}.Show)
		})
	})
	return r
}
