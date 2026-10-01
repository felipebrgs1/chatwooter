package schemaparity_test

import (
	"testing"

	sp "github.com/felipeborgaco/chatwooter/server/internal/schemaparity"
)

func sptr(s string) *string { return &s }

func trigger() sp.Trigger {
	return sp.Trigger{
		Table: "things", Timing: "BEFORE", Events: "INSERT", ForEach: "ROW", Function: "t_tr",
		Body: "BEGIN\n    NEW.kind := 1;\n    RETURN NEW;\nEND;",
	}
}

func pair() (*sp.Snapshot, *sp.Catalog) {
	bigint := "bigint"
	exp := &sp.Snapshot{
		Version:    "1",
		Extensions: []string{"vector"},
		Triggers:   map[string]sp.Trigger{"t_tr": trigger()},
		Tables: map[string]*sp.SnapshotTable{"things": {
			PrimaryKey: &bigint,
			Columns: map[string]sp.Column{
				"id":   {Type: "bigint", Default: sptr("sequence")},
				"kind": {Type: "integer", Nullable: false, Default: sptr("0")},
				"data": {Type: "jsonb", Nullable: true, Default: sptr(`{}`)},
			},
			Indexes:     map[string]sp.SnapshotIndex{"ix_kind": {Keys: []string{"kind"}, Using: "btree"}},
			ForeignKeys: map[string]sp.ForeignKey{},
			Checks:      map[string]string{"kind_positive": "kind >= 0"},
		}},
	}
	act := &sp.Catalog{
		Extensions: []string{"vector"},
		Triggers:   map[string]sp.Trigger{"t_tr": trigger()},
		Tables: map[string]*sp.CatalogTable{"things": {
			PrimaryKey: &sp.PrimaryKey{Column: "id", Type: "bigint"},
			Columns: map[string]sp.Column{
				"id":   {Type: "bigint", Default: sptr("nextval('things_id_seq'::regclass)")},
				"kind": {Type: "integer", Nullable: false, Default: sptr("0")},
				"data": {Type: "jsonb", Nullable: true, Default: sptr(`'{}'::jsonb`)},
			},
			Indexes: map[string]sp.CatalogIndex{"ix_kind": {
				Keys: []string{"kind"}, Using: "btree", Opclasses: []string{"int4_ops"}, Orders: []string{"ASC NULLS LAST"},
			}},
			ForeignKeys: map[string]sp.ForeignKey{},
			Checks:      map[string]string{"kind_positive": "CHECK ((kind >= 0))"},
		}},
	}
	return exp, act
}

func TestCompareEqualNormalizesPostgresForms(t *testing.T) {
	exp, act := pair()
	r := sp.Compare(exp, act)
	if !r.Summary.Parity {
		t.Fatalf("esperava paridade: %+v", r.Tables["things"])
	}
	if r.Triggers["t_tr"].Status != sp.Equal {
		t.Errorf("trigger = %v, want equal", r.Triggers["t_tr"].Status)
	}
}

func TestCompareDetectsDifferences(t *testing.T) {
	cases := map[string]func(*sp.Catalog){
		"default diferente": func(c *sp.Catalog) {
			col := c.Tables["things"].Columns["kind"]
			col.Default = sptr("1")
			c.Tables["things"].Columns["kind"] = col
		},
		"nulidade": func(c *sp.Catalog) {
			col := c.Tables["things"].Columns["kind"]
			col.Nullable = true
			c.Tables["things"].Columns["kind"] = col
		},
		"coluna local extra": func(c *sp.Catalog) {
			c.Tables["things"].Columns["extra"] = sp.Column{Type: "text", Nullable: true}
		},
		"índice ausente":  func(c *sp.Catalog) { delete(c.Tables["things"].Indexes, "ix_kind") },
		"check diferente": func(c *sp.Catalog) { c.Tables["things"].Checks["kind_positive"] = "CHECK ((kind > 0))" },
		"tabela ausente":  func(c *sp.Catalog) { delete(c.Tables, "things") },
		"extensão ausente": func(c *sp.Catalog) {
			c.Extensions = nil
		},
		"trigger ausente": func(c *sp.Catalog) { c.Triggers = map[string]sp.Trigger{} },
		"corpo do trigger diferente": func(c *sp.Catalog) {
			tr := trigger()
			tr.Body = "BEGIN IF NEW.kind IS NULL THEN NEW.kind := 1; END IF; RETURN NEW; END;"
			c.Triggers["t_tr"] = tr
		},
		"função do trigger com outro nome": func(c *sp.Catalog) {
			tr := trigger()
			tr.Function = "local_fn"
			c.Triggers["t_tr"] = tr
		},
		"timing do trigger": func(c *sp.Catalog) {
			tr := trigger()
			tr.Timing = "AFTER"
			c.Triggers["t_tr"] = tr
		},
	}
	for name, mutate := range cases {
		t.Run(name, func(t *testing.T) {
			exp, act := pair()
			mutate(act)
			if sp.Compare(exp, act).Summary.Parity {
				t.Fatal("deveria divergir")
			}
		})
	}
}

func TestCompareIndexOrderAndOpclass(t *testing.T) {
	exp, act := pair()
	exp.Tables["things"].Indexes["ix_kind"] = sp.SnapshotIndex{
		Keys: []string{"kind"}, Using: "btree", Order: map[string]string{"kind": "DESC NULLS LAST"},
	}
	if sp.Compare(exp, act).Summary.Parity {
		t.Fatal("ordem diferente deveria divergir")
	}

	exp, act = pair()
	op := "gin_trgm_ops"
	exp.Tables["things"].Indexes["ix_kind"] = sp.SnapshotIndex{Keys: []string{"kind"}, Using: "btree", Opclass: &op}
	if sp.Compare(exp, act).Summary.Parity {
		t.Fatal("opclass diferente deveria divergir")
	}
}
