package controllers

import (
	"errors"
	"net/http"
	"net/url"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

const (
	SessionCookie  = "chatwooter_session"
	accessTokenKey = "api_access_token"
)

// Authenticate exige usuário: header `api_access_token` (API) ou cookie de sessão (dashboard).
type Authenticate struct {
	Users    *models.Users
	Sessions *models.Sessions
}

func (a Authenticate) Require(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user, viaCookie, err := a.identify(r)
		if err != nil {
			if !errors.Is(err, models.ErrNotFound) {
				serverError(w, err)
				return
			}
			views.JSON(w, http.StatusUnauthorized, views.Errors("You need to sign in or sign up before continuing."))
			return
		}
		// Sessão por cookie é enviada sozinha pelo navegador: escritas precisam vir do nosso próprio site.
		if viaCookie && !isSafeMethod(r.Method) && !sameOrigin(r) {
			views.JSON(w, http.StatusForbidden, views.Error("Cross-origin request blocked"))
			return
		}
		r = with(r, userKey, user)
		next.ServeHTTP(w, with(r, viaCookieKey, viaCookie))
	})
}

func (a Authenticate) identify(r *http.Request) (user models.User, viaCookie bool, err error) {
	// Um token enviado e inválido não cai para o cookie: quem usa a API quer saber que errou.
	if token := r.Header.Get(accessTokenKey); token != "" {
		user, err = a.Users.ByAccessToken(r.Context(), token)
		return user, false, err
	}
	c, cookieErr := r.Cookie(SessionCookie)
	if cookieErr != nil {
		return models.User{}, false, models.ErrNotFound
	}
	user, err = a.Sessions.UserFor(r.Context(), c.Value)
	return user, true, err
}

func isSafeMethod(m string) bool {
	return m == http.MethodGet || m == http.MethodHead || m == http.MethodOptions
}

// sameOrigin aceita pedidos sem Origin (não são de navegador em contexto cross-site) e os do próprio host.
func sameOrigin(r *http.Request) bool {
	origin := r.Header.Get("Origin")
	if origin == "" {
		return true
	}
	u, err := url.Parse(origin)
	return err == nil && u.Host == r.Host
}

// AccountScope restringe /accounts/{account_id}/... aos membros da conta (mesmas respostas do Chatwoot:
// 404 para conta inexistente, 401 para quem não pertence a ela).
type AccountScope struct {
	Users    *models.Users
	Accounts *models.Accounts
}

func (s AccountScope) Require(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, err := strconv.ParseInt(chi.URLParam(r, "account_id"), 10, 32)
		if err != nil {
			notFoundJSON(w)
			return
		}
		accountID := int32(id)
		m, err := s.Users.MembershipFor(r.Context(), CurrentUser(r).ID, accountID)
		switch {
		case err == nil:
			next.ServeHTTP(w, with(r, membershipKey, m))
		case errors.Is(err, models.ErrNotFound):
			if _, err := s.Accounts.ByID(r.Context(), accountID); errors.Is(err, models.ErrNotFound) {
				notFoundJSON(w)
				return
			} else if err != nil {
				serverError(w, err)
				return
			}
			views.JSON(w, http.StatusUnauthorized, views.Error("You are not authorized to do this action"))
		default:
			serverError(w, err)
		}
	})
}

func notFoundJSON(w http.ResponseWriter) {
	views.JSON(w, http.StatusNotFound, views.Error("Resource could not be found"))
}

func serverError(w http.ResponseWriter, err error) {
	_ = err // o log entra com o middleware de logging (request id)
	views.JSON(w, http.StatusInternalServerError, views.Error("Internal Server Error"))
}
