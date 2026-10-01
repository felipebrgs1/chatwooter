package schemaparity_test

import (
	"context"
	"slices"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/db"
	sp "github.com/felipeborgaco/chatwooter/server/internal/schemaparity"
	"github.com/felipeborgaco/chatwooter/server/internal/testdb"
)

// Gate de paridade: o banco migrado pelo Go tem que ser igual ao schema.rb do Chatwoot.
func TestMigratedDatabaseMatchesUpstreamSnapshot(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatal(err)
	}
	snap, err := sp.LoadFile(upstream)
	if err != nil {
		t.Fatal(err)
	}
	cat, err := sp.LoadCatalog(ctx, pool)
	if err != nil {
		t.Fatal(err)
	}

	r := sp.Compare(snap, cat)
	s := r.Summary
	if s.UpstreamTables != 103 || s.MissingTables != 0 {
		t.Fatalf("tabelas: %d upstream, %d ausentes (%v)", s.UpstreamTables, s.MissingTables, r.MissingTables)
	}
	for name, td := range r.Tables {
		for _, d := range td.Differences() {
			t.Errorf("%s: %s", name, d)
		}
	}
	for name, d := range r.Extensions {
		if d.Status != sp.Equal {
			t.Errorf("extensão %s: %s", name, d.Status)
		}
	}
	if len(r.Triggers) != 4 {
		t.Errorf("triggers = %d, want 4", len(r.Triggers))
	}
	for name, d := range r.Triggers {
		if d.Status != sp.Equal {
			t.Errorf("trigger %s: %s", name, d.Status)
		}
	}
	if !s.Parity {
		t.Error("Summary.Parity = false")
	}

	// Tabelas a mais são toleradas pelo Compare; aqui elas são uma lista fechada.
	wantLocal := []string{
		"chatwooter_attachment_storage", "chatwooter_inbox_configs", "chatwooter_sessions", "goose_db_version",
		"river_job", "river_leader", "river_migration", "river_notification", "river_queue",
	}
	if !slices.Equal(r.LocalTables, wantLocal) {
		t.Errorf("tabelas locais = %v, want %v", r.LocalTables, wantLocal)
	}

	// Num banco sem contas não pode haver sequência solta (as conv/camp_dpid_seq_N nascem com cada conta).
	var loose []string
	if err := pool.QueryRow(ctx, `SELECT COALESCE(array_agg(c.relname ORDER BY c.relname), '{}')
		FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
		WHERE ns.nspname = current_schema() AND c.relkind = 'S'
		  AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype IN ('a', 'i'))`).Scan(&loose); err != nil {
		t.Fatal(err)
	}
	if len(loose) > 0 {
		t.Errorf("sequências soltas: %v", loose)
	}
}
