package router_test

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/router"
)

// Em produção o Go serve o build do dashboard no mesmo domínio da API (o cookie de sessão é same-site).
func TestServesDashboardBuild(t *testing.T) {
	dir := t.TempDir()
	write := func(name, body string) {
		t.Helper()
		path := filepath.Join(dir, name)
		if err := os.MkdirAll(filepath.Dir(path), 0o750); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	write("index.html", "<div id=app></div>")
	write("assets/app-abc123.js", "console.log(1)")
	h := router.New(router.Deps{WebDir: dir})

	get := func(path string) *httptest.ResponseRecorder {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
		return rec
	}

	for _, path := range []string{"/", "/app/accounts/1/conversations/7", "/app/login"} {
		rec := get(path)
		if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "id=app") {
			t.Errorf("GET %s = %d %q, want index.html", path, rec.Code, rec.Body.String())
		}
		if cc := rec.Header().Get("Cache-Control"); cc != "no-cache" {
			t.Errorf("GET %s Cache-Control = %q, want no-cache", path, cc)
		}
	}

	rec := get("/assets/app-abc123.js")
	if rec.Code != http.StatusOK || rec.Body.String() != "console.log(1)" {
		t.Errorf("asset = %d %q", rec.Code, rec.Body.String())
	}
	if cc := rec.Header().Get("Cache-Control"); !strings.Contains(cc, "immutable") {
		t.Errorf("asset Cache-Control = %q, want immutable", cc)
	}

	// Asset ausente e rota de API desconhecida são 404, nunca o index.html.
	for _, path := range []string{"/assets/missing.js", "/api/nope", "/auth/nope"} {
		if rec := get(path); rec.Code != http.StatusNotFound {
			t.Errorf("GET %s = %d, want 404", path, rec.Code)
		}
	}
}

func TestWithoutDashboardBuildUnknownPathsAre404(t *testing.T) {
	h := router.New(router.Deps{})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", rec.Code)
	}
}
