// Command schemadiff compara o PostgreSQL migrado ao schema.rb do Chatwoot (somente leitura).
// É diagnóstico: diferenças não mudam o código de saída; o gate de CI é o teste em internal/schemaparity.
package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/felipeborgaco/chatwooter/server/internal/config"
	"github.com/felipeborgaco/chatwooter/server/internal/schemaparity"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "schemadiff:", err)
		os.Exit(1)
	}
}

func run() error {
	snapshotPath := flag.String("snapshot", "../chatwoot/db/schema.rb", "caminho do schema.rb do Chatwoot")
	jsonPath := flag.String("json", "", "grava o relatório completo neste arquivo")
	flag.Parse()

	raw, err := os.ReadFile(*snapshotPath) //nolint:gosec // caminho vem do operador
	if err != nil {
		return err
	}
	snap, err := schemaparity.Parse(strings.NewReader(string(raw)))
	if err != nil {
		return err
	}

	cfg, err := config.Load(os.Getenv)
	if err != nil {
		return err
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer pool.Close()

	cat, err := schemaparity.LoadCatalog(ctx, pool)
	if err != nil {
		return err
	}
	report := schemaparity.Compare(snap, cat)

	s := report.Summary
	fmt.Printf("Chatwoot %s (SHA256 %x)\n", report.Version, sha256.Sum256(raw))
	fmt.Printf("Tabelas: %d/%d presentes; %d ausentes. Paridade estrutural: %v\n",
		s.ComparedTables, s.UpstreamTables, s.MissingTables, s.Parity)
	if len(report.MissingTables) > 0 {
		fmt.Println("Ausentes:", strings.Join(report.MissingTables, ", "))
	}
	if len(report.LocalTables) > 0 {
		fmt.Println("Locais:", strings.Join(report.LocalTables, ", "))
	}

	if *jsonPath == "" {
		return nil
	}
	out, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(*jsonPath), 0o750); err != nil {
		return err
	}
	if err := os.WriteFile(*jsonPath, append(out, '\n'), 0o600); err != nil { //nolint:gosec // caminho vem do operador
		return err
	}
	fmt.Println("Relatório:", *jsonPath)
	return nil
}
