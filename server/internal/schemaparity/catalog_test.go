package schemaparity_test

import (
	"context"
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
		if d.Status != sp.BodyUnverified {
			t.Errorf("trigger %s: %s", name, d.Status)
		}
	}
	if !s.Parity {
		t.Error("Summary.Parity = false")
	}
}
