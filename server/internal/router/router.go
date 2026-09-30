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
	System        models.System
	Users         *models.Users
	Sessions      *models.Sessions
	Accounts      *models.Accounts
	Conversations *models.Conversations
	SessionTTL    time.Duration
	CookieSecure  bool
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
		profile := controllers.Profile{Users: d.Users}
		r.Get("/profile", profile.Show)
		r.Put("/profile", profile.Update)
		r.Patch("/profile", profile.Update)
		r.Post("/profile/availability", profile.Availability)
		r.Post("/profile/auto_offline", profile.AutoOffline)
		r.Put("/profile/set_active_account", profile.SetActiveAccount)

		r.Route("/accounts/{account_id}", func(r chi.Router) {
			r.Use(scope.Require)
			r.Get("/", controllers.Accounts{Accounts: d.Accounts}.Show)

			convs := controllers.Conversations{Conversations: d.Conversations}
			msgs := controllers.Messages{Conversations: convs}
			r.Route("/conversations", func(r chi.Router) {
				r.Get("/", convs.Index)
				r.Get("/meta", convs.Meta)
				r.Route("/{conversation_id}", func(r chi.Router) {
					r.Get("/", convs.Show)
					r.Post("/toggle_status", convs.ToggleStatus)
					r.Post("/assignments", convs.Assign)
					r.Post("/update_last_seen", convs.UpdateLastSeen)
					r.Post("/unread", convs.Unread)
					r.Get("/messages", msgs.Index)
					r.Post("/messages", msgs.Create)
				})
			})
		})
	})
	return r
}
