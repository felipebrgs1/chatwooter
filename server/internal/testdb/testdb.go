// Package testdb entrega um banco Postgres real e isolado por teste.
package testdb

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	_ "github.com/jackc/pgx/v5/stdlib"
)

// New cria um banco novo (clone vazio), devolve o pool e o derruba no fim do teste.
// Usa TEST_DATABASE_URL (servidor onde o usuário pode criar bancos); pula o teste se ausente.
func New(t *testing.T) *pgxpool.Pool {
	t.Helper()
	pool, _ := NewWithURL(t)
	return pool
}

// NewWithURL é New devolvendo também a URL do banco criado (para testar comandos que recebem DATABASE_URL).
func NewWithURL(t *testing.T) (*pgxpool.Pool, string) {
	t.Helper()
	admin := os.Getenv("TEST_DATABASE_URL")
	if admin == "" {
		t.Skip("TEST_DATABASE_URL não definido")
	}
	name := fmt.Sprintf("cw_test_%d", time.Now().UnixNano())

	conn, err := sql.Open("pgx", admin)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := conn.Exec("CREATE DATABASE " + name); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = conn.Exec("DROP DATABASE " + name + " WITH (FORCE)")
		_ = conn.Close()
	})

	idx := strings.LastIndex(admin, "/")
	q := ""
	if i := strings.Index(admin[idx:], "?"); i >= 0 {
		q = admin[idx+i:]
	}
	url := admin[:idx+1] + name + q
	pool, err := pgxpool.New(context.Background(), url)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)
	return pool, url
}
