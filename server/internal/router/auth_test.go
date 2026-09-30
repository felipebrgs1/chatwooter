package router_test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/router"
	"github.com/felipeborgaco/chatwooter/server/internal/testdb"
)

const cookieName = "chatwooter_session"

type app struct {
	t       *testing.T
	handler http.Handler
	f       *factory.Factory
}

func newApp(t *testing.T) *app {
	t.Helper()
	pool, f := migratedPool(t)
	return &app{t: t, f: f, handler: router.New(router.Deps{
		System:        models.System{DB: pool},
		Users:         models.NewUsers(pool),
		Sessions:      models.NewSessions(pool, time.Hour),
		Accounts:      models.NewAccounts(pool),
		Conversations: models.NewConversations(pool),
		Labels:        models.NewLabels(pool),
		Teams:         models.NewTeams(pool),
		SessionTTL:    time.Hour,
	})}
}

func migratedPool(t *testing.T) (*testdbPool, *factory.Factory) {
	t.Helper()
	pool := testdb.New(t)
	if err := migrate(t, pool); err != nil {
		t.Fatal(err)
	}
	return pool, factory.New(t, pool)
}

type req struct {
	method, path, body string
	cookie             string
	header             map[string]string
}

func (a *app) do(r req) *httptest.ResponseRecorder {
	a.t.Helper()
	var body *strings.Reader
	if r.body != "" {
		body = strings.NewReader(r.body)
	} else {
		body = strings.NewReader("")
	}
	hr := httptest.NewRequest(r.method, r.path, body)
	hr.Host = "app.test"
	if r.body != "" {
		hr.Header.Set("Content-Type", "application/json")
	}
	if r.cookie != "" {
		hr.AddCookie(&http.Cookie{Name: cookieName, Value: r.cookie})
	}
	for k, v := range r.header {
		hr.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	a.handler.ServeHTTP(rec, hr)
	return rec
}

func (a *app) signIn(email, password string) *httptest.ResponseRecorder {
	a.t.Helper()
	b, _ := json.Marshal(map[string]string{"email": email, "password": password})
	return a.do(req{method: "POST", path: "/auth/sign_in", body: string(b)})
}

func sessionCookie(rec *httptest.ResponseRecorder) *http.Cookie {
	for _, c := range rec.Result().Cookies() {
		if c.Name == cookieName {
			return c
		}
	}
	return nil
}

func decode(t *testing.T, rec *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	var out map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatalf("corpo não é JSON: %q", rec.Body.String())
	}
	return out
}

func TestSignInSetsHardenedCookieAndReturnsProfile(t *testing.T) {
	a := newApp(t)
	account := a.f.Account()
	agent := a.f.User(account, func(u *factory.User) { u.Email = "ana@example.com"; u.Name = "Ana"; u.Role = 1 })

	rec := a.signIn("ana@example.com", factory.DefaultPassword)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d: %s", rec.Code, rec.Body)
	}
	c := sessionCookie(rec)
	if c == nil || c.Value == "" {
		t.Fatal("cookie de sessão ausente")
	}
	if !c.HttpOnly || c.SameSite != http.SameSiteLaxMode || c.Path != "/" {
		t.Errorf("cookie fraco: %+v", c)
	}

	data := decode(t, rec)["data"].(map[string]any)
	if data["email"] != "ana@example.com" || data["name"] != "Ana" || data["id"] != float64(agent.ID) {
		t.Errorf("data = %v", data)
	}
	if data["role"] != "administrator" || data["account_id"] != float64(account.ID) {
		t.Errorf("role/account_id = %v / %v", data["role"], data["account_id"])
	}
	accounts := data["accounts"].([]any)
	if len(accounts) != 1 || accounts[0].(map[string]any)["name"] != account.Name {
		t.Errorf("accounts = %v", accounts)
	}
	if _, leaked := data["encrypted_password"]; leaked {
		t.Error("hash de senha vazou na resposta")
	}
}

func TestSignInRejectsBadCredentials(t *testing.T) {
	a := newApp(t)
	a.f.User(a.f.Account(), func(u *factory.User) { u.Email = "ana@example.com" })

	for name, rec := range map[string]*httptest.ResponseRecorder{
		"senha errada":        a.signIn("ana@example.com", "errada"),
		"usuário inexistente": a.signIn("x@example.com", factory.DefaultPassword),
		"corpo inválido":      a.do(req{method: "POST", path: "/auth/sign_in", body: "{nao-json"}),
	} {
		if rec.Code != http.StatusUnauthorized {
			t.Errorf("%s: status = %d", name, rec.Code)
		}
		if sessionCookie(rec) != nil {
			t.Errorf("%s: não deveria criar sessão", name)
		}
		body := decode(t, rec)
		if body["success"] != false || len(body["errors"].([]any)) == 0 {
			t.Errorf("%s: corpo = %v", name, body)
		}
	}
}

func TestProfileRequiresAuthentication(t *testing.T) {
	a := newApp(t)
	agent := a.f.User(a.f.Account())
	cookie := sessionCookie(a.signIn(agent.Email, factory.DefaultPassword)).Value

	t.Run("com cookie", func(t *testing.T) {
		rec := a.do(req{method: "GET", path: "/api/v1/profile", cookie: cookie})
		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d", rec.Code)
		}
		body := decode(t, rec)
		if body["email"] != agent.Email || body["access_token"] != agent.AccessToken {
			t.Errorf("perfil = %v", body)
		}
	})
	t.Run("com api_access_token", func(t *testing.T) {
		rec := a.do(req{method: "GET", path: "/api/v1/profile", header: map[string]string{"api_access_token": agent.AccessToken}})
		if rec.Code != http.StatusOK || decode(t, rec)["id"] != float64(agent.ID) {
			t.Errorf("status = %d: %s", rec.Code, rec.Body)
		}
	})
	for name, r := range map[string]req{
		"sem credencial":  {method: "GET", path: "/api/v1/profile"},
		"cookie inválido": {method: "GET", path: "/api/v1/profile", cookie: "lixo"},
		"token inválido":  {method: "GET", path: "/api/v1/profile", header: map[string]string{"api_access_token": "lixo"}},
		"token e cookie ok só com token inválido": {method: "GET", path: "/api/v1/profile", cookie: cookie, header: map[string]string{"api_access_token": "lixo"}},
	} {
		t.Run(name, func(t *testing.T) {
			if rec := a.do(r); rec.Code != http.StatusUnauthorized {
				t.Errorf("status = %d, want 401", rec.Code)
			}
		})
	}
}

func TestSignOutRevokesSession(t *testing.T) {
	a := newApp(t)
	agent := a.f.User(a.f.Account())
	cookie := sessionCookie(a.signIn(agent.Email, factory.DefaultPassword)).Value

	rec := a.do(req{method: "DELETE", path: "/auth/sign_out", cookie: cookie})
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	if c := sessionCookie(rec); c == nil || c.MaxAge >= 0 {
		t.Errorf("cookie não foi expirado: %+v", c)
	}
	if rec := a.do(req{method: "GET", path: "/api/v1/profile", cookie: cookie}); rec.Code != http.StatusUnauthorized {
		t.Errorf("sessão ainda válida depois do logout: %d", rec.Code)
	}
	if rec := a.do(req{method: "DELETE", path: "/auth/sign_out"}); rec.Code != http.StatusNotFound {
		t.Errorf("logout sem sessão: %d, want 404", rec.Code)
	}
}

func TestCookieAuthenticatedWritesRejectCrossOrigin(t *testing.T) {
	a := newApp(t)
	agent := a.f.User(a.f.Account())
	cookie := sessionCookie(a.signIn(agent.Email, factory.DefaultPassword)).Value

	rec := a.do(req{method: "DELETE", path: "/auth/sign_out", cookie: cookie, header: map[string]string{"Origin": "https://evil.example"}})
	if rec.Code != http.StatusForbidden {
		t.Fatalf("Origin de outro site: status = %d, want 403", rec.Code)
	}
	if rec := a.do(req{method: "GET", path: "/api/v1/profile", cookie: cookie}); rec.Code != http.StatusOK {
		t.Error("a sessão não pode ter sido revogada pelo pedido bloqueado")
	}
	rec = a.do(req{method: "DELETE", path: "/auth/sign_out", cookie: cookie, header: map[string]string{"Origin": "http://app.test"}})
	if rec.Code != http.StatusOK {
		t.Errorf("mesma origem: status = %d", rec.Code)
	}
}

func TestAccountScope(t *testing.T) {
	a := newApp(t)
	mine, other := a.f.Account(), a.f.Account()
	agent := a.f.User(mine)
	cookie := sessionCookie(a.signIn(agent.Email, factory.DefaultPassword)).Value
	path := func(id int32) string { return "/api/v1/accounts/" + itoa(id) }

	rec := a.do(req{method: "GET", path: path(mine.ID), cookie: cookie})
	if rec.Code != http.StatusOK {
		t.Fatalf("membro: status = %d: %s", rec.Code, rec.Body)
	}
	body := decode(t, rec)
	if body["name"] != mine.Name || body["id"] != float64(mine.ID) || body["locale"] != "en" || body["status"] != "active" {
		t.Errorf("conta = %v", body)
	}

	if rec := a.do(req{method: "GET", path: path(other.ID), cookie: cookie}); rec.Code != http.StatusUnauthorized {
		t.Errorf("conta alheia: status = %d, want 401", rec.Code)
	}
	if rec := a.do(req{method: "GET", path: path(999999), cookie: cookie}); rec.Code != http.StatusNotFound {
		t.Errorf("conta inexistente: status = %d, want 404", rec.Code)
	}
	if rec := a.do(req{method: "GET", path: "/api/v1/accounts/abc", cookie: cookie}); rec.Code != http.StatusNotFound {
		t.Errorf("id inválido: status = %d, want 404", rec.Code)
	}
	if rec := a.do(req{method: "GET", path: path(mine.ID)}); rec.Code != http.StatusUnauthorized {
		t.Errorf("sem login: status = %d, want 401", rec.Code)
	}
	viaToken := a.do(req{method: "GET", path: path(mine.ID), header: map[string]string{"api_access_token": agent.AccessToken}})
	if viaToken.Code != http.StatusOK {
		t.Errorf("api_access_token: status = %d", viaToken.Code)
	}
}

func TestProfileUpdateEndpoints(t *testing.T) {
	a := newApp(t)
	one, two := a.f.Account(), a.f.Account()
	agent := a.f.User(one)
	a.f.Member(two, agent, 0)
	cookie := sessionCookie(a.signIn(agent.Email, factory.DefaultPassword)).Value
	do := func(method, path, body string) (int, map[string]any) {
		rec := a.do(req{method: method, path: path, body: body, cookie: cookie})
		var out map[string]any
		_ = json.Unmarshal(rec.Body.Bytes(), &out)
		return rec.Code, out
	}

	code, p := do("PUT", "/api/v1/profile", `{"profile":{"name":"Ana Souza","display_name":"Ana","ui_settings":{"sidebar_width":260}}}`)
	if code != http.StatusOK || p["name"] != "Ana Souza" || p["available_name"] != "Ana" || p["ui_settings"].(map[string]any)["sidebar_width"] != float64(260) {
		t.Errorf("PUT profile = %d %v", code, p)
	}
	if code, _ := do("PUT", "/api/v1/profile", `{"profile":{"name":""}}`); code != http.StatusUnprocessableEntity {
		t.Errorf("nome vazio: %d", code)
	}

	path := "/api/v1/profile/availability"
	code, p = do("POST", path, fmt.Sprintf(`{"profile":{"account_id":%d,"availability":"busy"}}`, one.ID))
	if code != http.StatusOK || p["accounts"].([]any)[0].(map[string]any)["availability"] != "busy" {
		t.Errorf("availability = %d %v", code, p["accounts"])
	}
	if code, _ := do("POST", path, fmt.Sprintf(`{"profile":{"account_id":%d,"availability":"voando"}}`, one.ID)); code != http.StatusUnprocessableEntity {
		t.Errorf("valor inválido: %d", code)
	}
	code, p = do("POST", "/api/v1/profile/auto_offline", fmt.Sprintf(`{"profile":{"account_id":%d,"auto_offline":false}}`, one.ID))
	if code != http.StatusOK || p["accounts"].([]any)[0].(map[string]any)["auto_offline"] != false {
		t.Errorf("auto_offline = %d", code)
	}

	if code, _ := do("PUT", "/api/v1/profile/set_active_account", fmt.Sprintf(`{"profile":{"account_id":%d}}`, two.ID)); code != http.StatusOK {
		t.Fatalf("set_active_account = %d", code)
	}
	if _, p := do("GET", "/api/v1/profile", ""); p["account_id"] != float64(two.ID) {
		t.Errorf("conta ativa = %v, want %d", p["account_id"], two.ID)
	}
	if code, _ := do("PUT", "/api/v1/profile/set_active_account", fmt.Sprintf(`{"profile":{"account_id":%d}}`, a.f.Account().ID)); code != http.StatusNotFound {
		t.Errorf("conta alheia: %d", code)
	}
}

// Atrás de um proxy reverso o Host chega reescrito; o site público vem em X-Forwarded-Host.
func TestCookieWritesAcceptTheForwardedPublicHost(t *testing.T) {
	a := newApp(t)
	agent := a.f.User(a.f.Account())
	cookie := sessionCookie(a.signIn(agent.Email, factory.DefaultPassword)).Value

	rec := a.do(req{method: "DELETE", path: "/auth/sign_out", cookie: cookie, header: map[string]string{
		"Origin": "https://chat.example.com", "X-Forwarded-Host": "chat.example.com",
	}})
	if rec.Code != http.StatusOK {
		t.Fatalf("Origin igual ao X-Forwarded-Host: status = %d, want 200", rec.Code)
	}

	cookie = sessionCookie(a.signIn(agent.Email, factory.DefaultPassword)).Value
	rec = a.do(req{method: "DELETE", path: "/auth/sign_out", cookie: cookie, header: map[string]string{
		"Origin": "https://evil.example", "X-Forwarded-Host": "chat.example.com",
	}})
	if rec.Code != http.StatusForbidden {
		t.Errorf("Origin de outro site continua bloqueado: status = %d, want 403", rec.Code)
	}
}
