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

// O hairtrigger cria uma função com o nome do trigger; o corpo é a ação + o RETURN que ele acrescenta.
func TestLoadUpstreamTriggers(t *testing.T) {
	s, err := schemaparity.LoadFile(upstream)
	if err != nil {
		t.Fatal(err)
	}
	want := map[string]schemaparity.Trigger{
		"accounts_after_insert_row_tr": {
			Table: "accounts", Timing: "AFTER", Events: "INSERT", ForEach: "ROW", Function: "accounts_after_insert_row_tr",
			Body: "BEGIN\n    execute format('create sequence IF NOT EXISTS conv_dpid_seq_%s', NEW.id);\n    RETURN NULL;\nEND;",
		},
		"conversations_before_insert_row_tr": {
			Table: "conversations", Timing: "BEFORE", Events: "INSERT", ForEach: "ROW",
			Function: "conversations_before_insert_row_tr",
			Body:     "BEGIN\n    NEW.display_id := nextval('conv_dpid_seq_' || NEW.account_id);\n    RETURN NEW;\nEND;",
		},
	}
	for name, w := range want {
		if got := s.Triggers[name]; got != w {
			t.Errorf("%s =\n%+v\nwant\n%+v", name, got, w)
		}
	}
	if got := s.Triggers["camp_dpid_before_insert"].Table; got != "accounts" {
		t.Errorf("camp_dpid_before_insert on %q", got)
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
