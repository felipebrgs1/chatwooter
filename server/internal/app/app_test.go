package app_test

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"net"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/app"
	"github.com/felipeborgaco/chatwooter/server/internal/db"
	"github.com/felipeborgaco/chatwooter/server/internal/factory"
	"github.com/felipeborgaco/chatwooter/server/internal/testdb"
)

func newKey(t *testing.T) string {
	t.Helper()
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		t.Fatal(err)
	}
	return base64.StdEncoding.EncodeToString(key)
}

func env(vars map[string]string) func(string) string {
	return func(k string) string { return vars[k] }
}

func TestUnknownCommandFails(t *testing.T) {
	err := app.Run(context.Background(), []string{"voar"}, env(nil), &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "voar") {
		t.Fatalf("err = %v", err)
	}
}

func TestServeRequiresEncryptionKey(t *testing.T) {
	err := app.Run(context.Background(), []string{"serve"}, env(map[string]string{"DATABASE_URL": "postgres://x/y"}), &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), "ENCRYPTION_KEY") {
		t.Fatalf("err = %v", err)
	}
}

func TestMigrateCommandCreatesSchema(t *testing.T) {
	pool, url := testdb.NewWithURL(t)
	out := &bytes.Buffer{}
	if err := app.Run(context.Background(), []string{"migrate"}, env(map[string]string{"DATABASE_URL": url}), out); err != nil {
		t.Fatal(err)
	}
	var n int
	if err := pool.QueryRow(context.Background(), `SELECT count(*) FROM pg_tables WHERE tablename IN ('accounts', 'river_job')`).Scan(&n); err != nil || n != 2 {
		t.Fatalf("tabelas = %d, %v", n, err)
	}
}

func TestEncryptProviderConfigsCommand(t *testing.T) {
	pool, url := testdb.NewWithURL(t)
	ctx := context.Background()
	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO chatwooter_inbox_configs (inbox_id, provider_config) VALUES (1, '{"bot_token":"segredo"}')`); err != nil {
		t.Fatal(err)
	}

	out := &bytes.Buffer{}
	vars := map[string]string{"DATABASE_URL": url, "ENCRYPTION_KEY": newKey(t)}
	if err := app.Run(ctx, []string{"encrypt-provider-configs"}, env(vars), out); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out.String(), "1") {
		t.Errorf("saída = %q", out.String())
	}
	var raw string
	if err := pool.QueryRow(ctx, `SELECT provider_config::text FROM chatwooter_inbox_configs WHERE inbox_id = 1`).Scan(&raw); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(raw, "segredo") {
		t.Errorf("token continua em texto claro: %s", raw)
	}
}

func TestServeAnswersHealthAndStopsOnCancel(t *testing.T) {
	_, url := testdb.NewWithURL(t)
	if err := app.Run(context.Background(), []string{"migrate"}, env(map[string]string{"DATABASE_URL": url}), &bytes.Buffer{}); err != nil {
		t.Fatal(err)
	}
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	port := fmt.Sprint(ln.Addr().(*net.TCPAddr).Port)
	_ = ln.Close()

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	vars := map[string]string{"DATABASE_URL": url, "ENCRYPTION_KEY": newKey(t), "PORT": port}
	go func() { done <- app.Run(ctx, []string{"serve"}, env(vars), &bytes.Buffer{}) }()

	deadline := time.After(10 * time.Second)
	tick := time.NewTicker(50 * time.Millisecond)
	defer tick.Stop()
	for ok := false; !ok; {
		select {
		case err := <-done:
			t.Fatalf("serve terminou antes da hora: %v", err)
		case <-deadline:
			t.Fatal("/health não respondeu")
		case <-tick.C:
			resp, err := http.Get("http://127.0.0.1:" + port + "/health") //nolint:noctx // teste local
			if err == nil {
				ok = resp.StatusCode == http.StatusOK
				_ = resp.Body.Close()
			}
		}
	}

	cancel()
	select {
	case err := <-done:
		if err != nil {
			t.Errorf("shutdown com erro: %v", err)
		}
	case <-time.After(10 * time.Second):
		t.Fatal("serve não parou depois do cancel")
	}
}

func TestServeSignsInARealUser(t *testing.T) {
	pool, url := testdb.NewWithURL(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatal(err)
	}
	agent := factory.New(t, pool).User(factory.New(t, pool).Account())

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	port := fmt.Sprint(ln.Addr().(*net.TCPAddr).Port)
	_ = ln.Close()
	vars := map[string]string{"DATABASE_URL": url, "ENCRYPTION_KEY": newKey(t), "PORT": port}
	done := make(chan error, 1)
	go func() { done <- app.Run(ctx, []string{"serve"}, env(vars), &bytes.Buffer{}) }()

	body := fmt.Sprintf(`{"email":%q,"password":%q}`, agent.Email, factory.DefaultPassword)
	deadline := time.After(10 * time.Second)
	for {
		select {
		case err := <-done:
			t.Fatalf("serve terminou: %v", err)
		case <-deadline:
			t.Fatal("login não respondeu")
		default:
		}
		req, _ := http.NewRequestWithContext(ctx, http.MethodPost, "http://127.0.0.1:"+port+"/auth/sign_in", strings.NewReader(body))
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			time.Sleep(50 * time.Millisecond)
			continue
		}
		defer func() { _ = resp.Body.Close() }()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("status = %d", resp.StatusCode)
		}
		for _, c := range resp.Cookies() {
			if c.Name == "chatwooter_session" && c.HttpOnly {
				return
			}
		}
		t.Fatal("cookie de sessão ausente")
	}
}
