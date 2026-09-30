package schemaparity_test

import (
	"strings"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/schemaparity"
)

// Cópia congelada de chatwoot/db/schema.rb (o clone em chatwoot/ não é versionado).
const upstream = "testdata/schema.rb"

func TestLoadUpstreamSnapshot(t *testing.T) {
	s, err := schemaparity.LoadFile(upstream)
	if err != nil {
		t.Fatal(err)
	}
	if s.Version != "2026_09_24_000000" {
		t.Errorf("Version = %q", s.Version)
	}
	if len(s.Tables) != 103 {
		t.Errorf("tabelas = %d, want 103", len(s.Tables))
	}
	if len(s.Triggers) != 4 {
		t.Errorf("triggers = %d, want 4", len(s.Triggers))
	}
	if !contains(s.Extensions, "vector") {
		t.Errorf("extensões = %v, falta vector", s.Extensions)
	}
}

func TestParseColumnsAndIndexes(t *testing.T) {
	src := `ActiveRecord::Schema[7.1].define(version: 2026_01_01_000000) do
  enable_extension "pg_trgm"

  create_table "things", force: :cascade do |t|
    t.string "name", limit: 10, null: false
    t.datetime "created_at", precision: nil
    t.jsonb "data", default: {}
    t.integer "kind", default: 0, null: false
    t.index ["name"], name: "index_things_on_name", unique: true
    t.check_constraint "kind >= 0", name: "kind_positive"
  end

  create_table "links", id: :serial, force: :cascade do |t|
    t.bigint "thing_id", null: false
  end

  add_foreign_key "links", "things", on_delete: :cascade
end
`
	s, err := schemaparity.Parse(strings.NewReader(src))
	if err != nil {
		t.Fatal(err)
	}
	things := s.Tables["things"]
	if pk := things.PrimaryKey; pk == nil || *pk != "bigint" {
		t.Errorf("PK things = %v", pk)
	}
	if c := things.Columns["name"]; c.Type != "character varying(10)" || c.Nullable {
		t.Errorf("name = %+v", c)
	}
	if c := things.Columns["created_at"]; c.Type != "timestamp without time zone" || c.Precision != nil {
		t.Errorf("created_at = %+v", c)
	}
	if ix := things.Indexes["index_things_on_name"]; !ix.Unique || ix.Using != "btree" {
		t.Errorf("índice = %+v", ix)
	}
	if things.Checks["kind_positive"] != "kind >= 0" {
		t.Errorf("checks = %v", things.Checks)
	}
	if pk := s.Tables["links"].PrimaryKey; pk == nil || *pk != "integer" {
		t.Errorf("PK links = %v", pk)
	}
	if fk := s.Tables["links"].ForeignKeys["thing_id"]; fk.Table != "things" || fk.OnDelete != "cascade" {
		t.Errorf("fk = %+v", fk)
	}
}

func TestParseFailsClosedOnUnknownInstruction(t *testing.T) {
	src := "ActiveRecord::Schema[7.1].define(version: 1) do\n  create_view \"x\"\nend\n"
	if _, err := schemaparity.Parse(strings.NewReader(src)); err == nil {
		t.Fatal("instrução desconhecida deve falhar")
	}
}

func TestParseRequiresVersion(t *testing.T) {
	if _, err := schemaparity.Parse(strings.NewReader("")); err == nil {
		t.Fatal("sem versão deve falhar")
	}
}

func contains(list []string, v string) bool {
	for _, s := range list {
		if s == v {
			return true
		}
	}
	return false
}
