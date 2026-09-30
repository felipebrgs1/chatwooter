package controllers

import (
	"context"
	"net/http"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

type ctxKey int

const (
	userKey ctxKey = iota
	membershipKey
	viaCookieKey
)

// CurrentUser é o usuário autenticado; só existe atrás do middleware Authenticate.Require.
func CurrentUser(r *http.Request) models.User {
	u, _ := r.Context().Value(userKey).(models.User)
	return u
}

// CurrentMembership é o vínculo do usuário com a conta da URL; só existe atrás de AccountScope.Require.
func CurrentMembership(r *http.Request) models.Membership {
	m, _ := r.Context().Value(membershipKey).(models.Membership)
	return m
}

func with(r *http.Request, key ctxKey, v any) *http.Request {
	return r.WithContext(context.WithValue(r.Context(), key, v))
}
