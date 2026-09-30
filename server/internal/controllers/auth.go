package controllers

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

// Auth é o login do dashboard (mesmas rotas do devise_token_auth: /auth/sign_in e /auth/sign_out).
type Auth struct {
	Users        *models.Users
	Sessions     *models.Sessions
	SessionTTL   time.Duration
	CookieSecure bool
}

const maxBody = 1 << 20

func (c Auth) SignIn(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxBody)
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		badCredentials(w)
		return
	}

	user, err := c.Users.Authenticate(r.Context(), in.Email, in.Password)
	if errors.Is(err, models.ErrInvalidCredentials) {
		badCredentials(w)
		return
	}
	if err != nil {
		serverError(w, err)
		return
	}
	profile, err := c.Users.Profile(r.Context(), user.ID)
	if err != nil {
		serverError(w, err)
		return
	}
	token, err := c.Sessions.Create(r.Context(), user.ID)
	if err != nil {
		serverError(w, err)
		return
	}
	http.SetCookie(w, c.cookie(token, int(c.SessionTTL.Seconds())))
	views.JSON(w, http.StatusOK, views.SignIn(profile))
}

func (c Auth) SignOut(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie(SessionCookie)
	if err != nil || cookie.Value == "" {
		views.JSON(w, http.StatusNotFound, views.AuthErrors("User was not found or was not logged in."))
		return
	}
	if !sameOrigin(r) {
		views.JSON(w, http.StatusForbidden, views.Error("Cross-origin request blocked"))
		return
	}
	if err := c.Sessions.Revoke(r.Context(), cookie.Value); err != nil {
		serverError(w, err)
		return
	}
	http.SetCookie(w, c.cookie("", -1))
	views.JSON(w, http.StatusOK, views.Success())
}

func (c Auth) cookie(value string, maxAge int) *http.Cookie {
	// Secure é configurável: em desenvolvimento o app roda em http.
	return &http.Cookie{ //nolint:gosec // G124: Secure vem de COOKIE_SECURE
		Name:     SessionCookie,
		Value:    value,
		Path:     "/",
		MaxAge:   maxAge,
		HttpOnly: true,
		Secure:   c.CookieSecure,
		SameSite: http.SameSiteLaxMode,
	}
}

func badCredentials(w http.ResponseWriter) {
	views.JSON(w, http.StatusUnauthorized, views.AuthErrors("Invalid login credentials. Please try again."))
}
