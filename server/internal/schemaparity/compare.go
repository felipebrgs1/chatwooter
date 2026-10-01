package schemaparity

import (
	"encoding/json"
	"fmt"
	"reflect"
	"regexp"
	"slices"
	"sort"
	"strconv"
	"strings"
)

type Status string

const (
	Equal     Status = "equal"
	Different Status = "different"
	Missing   Status = "missing"
	LocalOnly Status = "local_only"
)

type Diff struct {
	Status   Status `json:"status"`
	Expected any    `json:"expected"`
	Actual   any    `json:"actual"`
}

type TableDiff struct {
	Status         Status          `json:"status"` // present | missing
	PrimaryKey     Diff            `json:"primary_key"`
	Columns        map[string]Diff `json:"columns"`
	MissingColumns []string        `json:"missing_columns"`
	LocalColumns   []string        `json:"local_columns"`
	Indexes        map[string]Diff `json:"indexes"`
	ForeignKeys    map[string]Diff `json:"foreign_keys"`
	Checks         map[string]Diff `json:"checks"`
}

type Summary struct {
	UpstreamTables int  `json:"upstream_tables"`
	LocalTables    int  `json:"local_tables"`
	MissingTables  int  `json:"missing_tables"`
	ComparedTables int  `json:"compared_tables"`
	Parity         bool `json:"parity"`
}

type Report struct {
	Version       string               `json:"version"`
	Limitations   []string             `json:"limitations"`
	Extensions    map[string]Diff      `json:"extensions"`
	Triggers      map[string]Diff      `json:"triggers"`
	MissingTables []string             `json:"missing_tables"`
	LocalTables   []string             `json:"local_tables"`
	Tables        map[string]TableDiff `json:"tables"`
	Summary       Summary              `json:"summary"`
}

// Equal diz se a tabela não tem nenhuma diferença.
func (t TableDiff) Equal() bool { return len(t.Differences()) == 0 }

// Differences lista, em texto, tudo que não é igual na tabela.
func (t TableDiff) Differences() []string {
	var out []string
	if t.Status == Missing {
		out = append(out, "tabela ausente")
	}
	if t.PrimaryKey.Status != Equal {
		out = append(out, fmt.Sprintf("primary key: esperado %v, atual %v", t.PrimaryKey.Expected, t.PrimaryKey.Actual))
	}
	for _, c := range t.MissingColumns {
		out = append(out, "coluna ausente: "+c)
	}
	for _, c := range t.LocalColumns {
		out = append(out, "coluna local sobrando: "+c)
	}
	for kind, m := range map[string]map[string]Diff{
		"coluna": t.Columns, "índice": t.Indexes, "fk": t.ForeignKeys, "check": t.Checks,
	} {
		for name, d := range m {
			if d.Status != Equal {
				out = append(out, fmt.Sprintf("%s %s: %s (esperado %v, atual %v)", kind, name, d.Status, d.Expected, d.Actual))
			}
		}
	}
	sort.Strings(out)
	return out
}

// Compare confronta o catálogo físico com o snapshot. Nunca falha: diferenças viram o relatório.
func Compare(expected *Snapshot, actual *Catalog) Report {
	var upstream, local, missing, extra []string
	for name := range expected.Tables {
		upstream = append(upstream, name)
		if _, ok := actual.Tables[name]; !ok {
			missing = append(missing, name)
		}
	}
	for name := range actual.Tables {
		local = append(local, name)
		if _, ok := expected.Tables[name]; !ok {
			extra = append(extra, name)
		}
	}
	sort.Strings(upstream)
	sort.Strings(missing)
	sort.Strings(extra)

	tables := make(map[string]TableDiff, len(upstream))
	allEqual := true
	for _, name := range upstream {
		td := compareTable(expected.Tables[name], actual.Tables[name])
		tables[name] = td
		allEqual = allEqual && td.Equal()
	}

	extensions := compareNamed(toSet(expected.Extensions), toSet(actual.Extensions), func(bool, bool) bool { return true })
	triggers := compareNamed(expected.Triggers, actual.Triggers, func(want, got Trigger) bool {
		body := normalizeSQL(want.Body) == normalizeSQL(got.Body)
		want.Body, got.Body = "", ""
		return body && want == got
	})

	parity := len(missing) == 0 && allEqual && allStatus(extensions, Equal) && allStatus(triggers, Equal)

	return Report{
		Version: expected.Version,
		Limitations: []string{
			"Enums Rails, transformações de importação e dados não constam do schema.rb",
			"Corpo dos triggers comparado ao SQL que o hairtrigger gera, sem diferenciar maiúsculas nem espaços",
			"Índices comparados por nome, chaves, unicidade, método, predicado, opclasses declaradas e ordem por coluna",
		},
		Extensions:    extensions,
		Triggers:      triggers,
		MissingTables: emptyIfNil(missing),
		LocalTables:   emptyIfNil(extra),
		Tables:        tables,
		Summary: Summary{
			UpstreamTables: len(upstream),
			LocalTables:    len(local),
			MissingTables:  len(missing),
			ComparedTables: len(upstream) - len(missing),
			Parity:         parity,
		},
	}
}

func compareTable(src *SnapshotTable, dst *CatalogTable) TableDiff {
	td := TableDiff{Status: "present"}
	if dst == nil {
		td.Status = Missing
		dst = &CatalogTable{
			Columns: map[string]Column{}, Indexes: map[string]CatalogIndex{},
			ForeignKeys: map[string]ForeignKey{}, Checks: map[string]string{},
		}
	}

	var wantPK, gotPK *PrimaryKey
	if src.PrimaryKey != nil {
		wantPK = &PrimaryKey{Column: "id", Type: *src.PrimaryKey}
	}
	gotPK = dst.PrimaryKey
	td.PrimaryKey = Diff{Status: statusOf(reflect.DeepEqual(wantPK, gotPK)), Expected: wantPK, Actual: gotPK}

	td.Columns = compareNamed(src.Columns, dst.Columns, compareColumn)
	td.MissingColumns = emptyIfNil(sortedKeysMissing(src.Columns, dst.Columns))
	td.LocalColumns = emptyIfNil(sortedKeysMissing(dst.Columns, src.Columns))
	td.Indexes = compareNamed(src.Indexes, dst.Indexes, compareIndex)
	td.ForeignKeys = compareNamed(src.ForeignKeys, dst.ForeignKeys, func(a, b ForeignKey) bool { return a == b })
	td.Checks = compareNamed(src.Checks, dst.Checks, func(want, got string) bool {
		return normalizeSQL(want) == normalizeCheck(got)
	})
	return td
}

func compareColumn(want, got Column) bool {
	return want.Type == got.Type && want.Nullable == got.Nullable &&
		reflect.DeepEqual(want.Precision, got.Precision) &&
		normalizeColumnDefault(want.Type, want.Default) == normalizeColumnDefault(got.Type, got.Default)
}

func compareIndex(want SnapshotIndex, got CatalogIndex) bool {
	if want.Unique != got.Unique || want.Using != got.Using || normalizePtr(want.Where) != normalizePtr(got.Where) {
		return false
	}
	if want.Expression != nil {
		if normalizeSQL(*want.Expression) != normalizeSQL(strings.Join(got.Keys, ", ")) {
			return false
		}
	} else if !slices.Equal(mapSlice(want.Keys, normalizeSQL), mapSlice(got.Keys, normalizeSQL)) {
		return false
	}
	if want.Opclass != nil {
		for _, oc := range got.Opclasses {
			if oc != *want.Opclass {
				return false
			}
		}
	}
	return slices.Equal(indexOrders(want, got), got.Orders)
}

func indexOrders(want SnapshotIndex, got CatalogIndex) []string {
	out := make([]string, len(got.Keys))
	if want.Using != "btree" {
		return out
	}
	keys := want.Keys
	if want.Expression != nil {
		keys = got.Keys
	}
	out = out[:0]
	for _, k := range keys {
		o, ok := want.Order[k]
		if !ok {
			o = "ASC NULLS LAST"
		}
		out = append(out, o)
	}
	return out
}

func compareNamed[E, A any](expected map[string]E, actual map[string]A, eq func(E, A) bool) map[string]Diff {
	out := make(map[string]Diff, len(expected))
	for name, want := range expected {
		got, ok := actual[name]
		if !ok {
			out[name] = Diff{Status: Missing, Expected: want}
			continue
		}
		out[name] = Diff{Status: statusOf(eq(want, got)), Expected: want, Actual: got}
	}
	for name, got := range actual {
		if _, ok := expected[name]; !ok {
			out[name] = Diff{Status: LocalOnly, Actual: got}
		}
	}
	return out
}

func statusOf(equal bool) Status {
	if equal {
		return Equal
	}
	return Different
}

func allStatus(m map[string]Diff, want Status) bool {
	for _, d := range m {
		if d.Status != want {
			return false
		}
	}
	return true
}

func toSet(list []string) map[string]bool {
	m := make(map[string]bool, len(list))
	for _, s := range list {
		m[s] = true
	}
	return m
}

func sortedKeysMissing[A, B any](a map[string]A, b map[string]B) []string {
	var out []string
	for k := range a {
		if _, ok := b[k]; !ok {
			out = append(out, k)
		}
	}
	sort.Strings(out)
	return out
}

func emptyIfNil(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}

func mapSlice(in []string, f func(string) string) []string {
	out := make([]string, len(in))
	for i, s := range in {
		out[i] = f(s)
	}
	return out
}

// ---- normalização de defaults e SQL ----

var (
	reCast      = regexp.MustCompile(`::[\w\s\[\]]+$`)
	reParenWrap = regexp.MustCompile(`^\('(.+)'\)$`)
	reSpaces    = regexp.MustCompile(`\s+`)
	reParenCast = regexp.MustCompile(`\(([a-z_][a-z_0-9]*)\)::`)
)

// normalizeColumnDefault devolve uma chave comparável; "<nil>" é distinto de string vazia.
func normalizeColumnDefault(typ string, value *string) string {
	if value == nil {
		return "<nil>"
	}
	n := normalizeDefault(*value)
	switch {
	case typ == "text[]" && (n == "[]" || n == "ARRAY[]"):
		return "{}"
	case typ == "double precision":
		if f, err := strconv.ParseFloat(n, 64); err == nil {
			return "float:" + strconv.FormatFloat(f, 'g', -1, 64)
		}
	case typ == "json" || typ == "jsonb":
		var v any
		if err := json.Unmarshal([]byte(n), &v); err == nil {
			b, _ := json.Marshal(v)
			return "json:" + string(b)
		}
	}
	return n
}

func normalizeDefault(v string) string {
	switch {
	case v == "{}" || v == "[]":
		return v
	case strings.HasPrefix(v, "nextval("):
		return "sequence"
	}
	v = reCast.ReplaceAllString(v, "")
	v = strings.Trim(v, "'")
	return reParenWrap.ReplaceAllString(v, "$1")
}

func normalizePtr(s *string) string {
	if s == nil {
		return "<nil>"
	}
	return normalizeSQL(*s)
}

func normalizeSQL(sql string) string {
	sql = strings.ToLower(sql)
	sql = reSpaces.ReplaceAllString(sql, "")
	sql = reParenCast.ReplaceAllString(sql, "${1}::")
	return stripOuterParens(sql)
}

// pg_get_constraintdef sempre devolve CHECK ((...)); o snapshot guarda a expressão do Rails pura.
func normalizeCheck(sql string) string {
	return stripOuterParens(strings.TrimPrefix(normalizeSQL(sql), "check"))
}

func stripOuterParens(sql string) string {
	for strings.HasPrefix(sql, "(") && strings.HasSuffix(sql, ")") {
		inner := sql[1 : len(sql)-1]
		if !balanced(inner) {
			break
		}
		sql = inner
	}
	return sql
}

func balanced(s string) bool {
	depth := 0
	for _, r := range s {
		switch r {
		case '(':
			depth++
		case ')':
			if depth == 0 {
				return false
			}
			depth--
		}
	}
	return depth == 0
}
