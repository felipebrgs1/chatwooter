// Package schemaparity compara o catálogo de um PostgreSQL migrado com o schema.rb do Chatwoot.
// Os nomes fazem parte do contrato: um campo transformado é reportado, nunca aceito em silêncio.
package schemaparity

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"regexp"
	"sort"
	"strings"
)

type Column struct {
	Type      string
	Nullable  bool
	Default   *string
	Precision *int
}

type SnapshotIndex struct {
	Keys       []string
	Expression *string
	Unique     bool
	Using      string
	Where      *string
	Opclass    *string
	Order      map[string]string
}

type ForeignKey struct {
	Table    string
	OnDelete string
}

type SnapshotTable struct {
	PrimaryKey  *string // tipo da coluna id; nil quando `id: false`
	Columns     map[string]Column
	Indexes     map[string]SnapshotIndex
	ForeignKeys map[string]ForeignKey
	Checks      map[string]string
}

// Trigger descreve o que o hairtrigger cria: uma função plpgsql com o nome do trigger, ligada à tabela.
type Trigger struct {
	Table    string
	Timing   string // BEFORE | AFTER
	Events   string // INSERT, UPDATE... separados por " OR "
	ForEach  string // ROW | STATEMENT
	Function string
	Body     string // corpo da função, sem as aspas $$
}

type Snapshot struct {
	Version    string
	Extensions []string
	Tables     map[string]*SnapshotTable
	Triggers   map[string]Trigger
}

var columnTypes = map[string]bool{
	"string": true, "text": true, "integer": true, "bigint": true, "boolean": true, "datetime": true,
	"date": true, "float": true, "json": true, "jsonb": true, "uuid": true, "vector": true,
}

var (
	reVersion    = regexp.MustCompile(`^ActiveRecord::Schema\[.*\]\.define\(version: ([\d_]+)\) do$`)
	reTrigger    = regexp.MustCompile(`^  create_trigger\("([^"]+)".*$`)
	reTriggerOn  = regexp.MustCompile(`^      on\("([^"]+)"\)\.$`)
	reTriggerArg = regexp.MustCompile(`^      (name|before|after|for_each)\(([^)]+)\)(?:\.| do)$`)
	reTriggerSQL = regexp.MustCompile(`^    "(.+)"$`)
	reExtension  = regexp.MustCompile(`^  enable_extension "([^"]+)"$`)
	reTable      = regexp.MustCompile(`^  create_table "([^"]+)"(.*) do \|t\|$`)
	reForeignKey = regexp.MustCompile(`^  add_foreign_key "([^"]+)", "([^"]+)"(.*)$`)
	reCheck      = regexp.MustCompile(`^    t.check_constraint "([^"]+)", name: "([^"]+)"$`)
	reIndex      = regexp.MustCompile(`^    t.index (.+), name: "([^"]+)"(.*)$`)
	reColumn     = regexp.MustCompile(`^    t\.(\w+) "([^"]+)"(.*)$`)

	reQuoted         = regexp.MustCompile(`"([^"]+)"`)
	reInlineOps      = regexp.MustCompile(` (\w+_ops)"$`)
	reTrailingOps    = regexp.MustCompile(` \w+_ops$`)
	reOrder          = regexp.MustCompile(`order: \{([^}]+)\}`)
	reOrderEntry     = regexp.MustCompile(`(\w+): "([^"]+)"`)
	reDefaultProc    = regexp.MustCompile(`default: -> \{ "([^"]+)" \}`)
	reDefault        = regexp.MustCompile(`default: ("[^"]*"|\{[^}]*\}|\[[^\]]*\]|true|false|-?\d+(?:\.\d+)?)`)
	reHashArrow      = regexp.MustCompile(`"\s*=>`)
	reExplicitReturn = regexp.MustCompile(`(?i)return [^;]+;\s*$`)
	reStringOption   = `(?:^|, )%s: (?:"([^"]*)"|:([a-z_]+)|(-?\d+))`
)

func LoadFile(path string) (*Snapshot, error) {
	f, err := os.Open(path) //nolint:gosec // caminho vem do operador (flag)
	if err != nil {
		return nil, err
	}
	defer func() { _ = f.Close() }()
	return Parse(f)
}

// Parse lê o schema.rb como dado, sem nunca avaliar Ruby. Instrução desconhecida falha.
func Parse(r io.Reader) (*Snapshot, error) {
	s := &Snapshot{Tables: map[string]*SnapshotTable{}, Triggers: map[string]Trigger{}}
	var table, trigger string

	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for n := 1; sc.Scan(); n++ {
		line := strings.TrimRight(sc.Text(), " \t\r")
		var err error
		switch {
		case trigger != "":
			trigger, err = parseTriggerLine(s, trigger, line, n)
		case table != "":
			table, err = parseTableLine(s.Tables[table], table, line, n)
		default:
			table, trigger, err = parseTopLine(s, line, n)
		}
		if err != nil {
			return nil, err
		}
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	switch {
	case s.Version == "":
		return nil, fmt.Errorf("missing Rails schema version")
	case table != "":
		return nil, fmt.Errorf("unterminated table %s", table)
	case trigger != "":
		return nil, fmt.Errorf("unterminated trigger %s", trigger)
	}
	return s, nil
}

func parseTriggerLine(s *Snapshot, name, line string, n int) (string, error) {
	tr := s.Triggers[name]
	switch m := reTriggerArg.FindStringSubmatch(line); {
	case reTriggerOn.MatchString(line):
		tr.Table = reTriggerOn.FindStringSubmatch(line)[1]
	case m != nil && m[1] == "name":
		tr.Function = strings.Trim(m[2], `"`)
	case m != nil && m[1] == "for_each":
		tr.ForEach = strings.ToUpper(strings.TrimPrefix(m[2], ":"))
	case m != nil:
		tr.Timing = strings.ToUpper(m[1])
		var events []string
		for _, e := range strings.Split(m[2], ",") {
			events = append(events, strings.ToUpper(strings.TrimPrefix(strings.TrimSpace(e), ":")))
		}
		sort.Strings(events) // mesma ordem que o catálogo
		tr.Events = strings.Join(events, " OR ")
	case reTriggerSQL.MatchString(line):
		tr.Body = hairtriggerBody(tr, reTriggerSQL.FindStringSubmatch(line)[1])
	case line == "  end":
		s.Triggers[name] = tr
		return "", nil
	default:
		return name, unsupported(n, line)
	}
	s.Triggers[name] = tr
	return name, nil
}

// hairtriggerBody reproduz o corpo gerado pelo hairtrigger (Builder#generate_trigger_postgresql):
// a ação indentada e, sem RETURN explícito, RETURN NULL (AFTER/STATEMENT) ou RETURN NEW.
func hairtriggerBody(tr Trigger, action string) string {
	body := "BEGIN\n    " + action + "\n"
	if !reExplicitReturn.MatchString(action) {
		ret := "NEW"
		switch {
		case tr.Timing == "AFTER" || tr.ForEach == "STATEMENT":
			ret = "NULL"
		case strings.Contains(tr.Events, "DELETE"):
			ret = "OLD"
		}
		body += "    RETURN " + ret + ";\n"
	}
	return body + "END;"
}

func parseTableLine(t *SnapshotTable, name, line string, n int) (string, error) {
	if line == "  end" {
		return "", nil
	}
	if m := reCheck.FindStringSubmatch(line); m != nil {
		t.Checks[m[2]] = m[1]
		return name, nil
	}
	if m := reIndex.FindStringSubmatch(line); m != nil {
		t.Indexes[m[2]] = parseIndex(m[1], m[3])
		return name, nil
	}
	if m := reColumn.FindStringSubmatch(line); m != nil {
		if !columnTypes[m[1]] {
			return name, unsupported(n, line)
		}
		col, err := parseColumn(m[1], m[3])
		if err != nil {
			return name, fmt.Errorf("line %d: %w", n, err)
		}
		t.Columns[m[2]] = col
		return name, nil
	}
	return name, unsupported(n, line)
}

func parseTopLine(s *Snapshot, line string, n int) (table, trigger string, err error) {
	trimmed := strings.TrimSpace(line)
	if trimmed == "" || trimmed == "end" || strings.HasPrefix(trimmed, "#") {
		return "", "", nil
	}
	switch {
	case reVersion.MatchString(line):
		s.Version = reVersion.FindStringSubmatch(line)[1]
	case reTrigger.MatchString(line):
		trigger = reTrigger.FindStringSubmatch(line)[1]
		s.Triggers[trigger] = Trigger{Function: trigger}
	case reExtension.MatchString(line):
		s.Extensions = append(s.Extensions, reExtension.FindStringSubmatch(line)[1])
	case reTable.MatchString(line):
		m := reTable.FindStringSubmatch(line)
		s.Tables[m[1]] = newTable(m[2])
		table = m[1]
	case reForeignKey.MatchString(line):
		m := reForeignKey.FindStringSubmatch(line)
		from, ok := s.Tables[m[1]]
		if !ok {
			return "", "", fmt.Errorf("line %d: foreign key from unknown table %s", n, m[1])
		}
		column := option(m[3], "column")
		if column == "" {
			column = singularize(m[2]) + "_id"
		}
		onDelete := option(m[3], "on_delete")
		if onDelete == "" {
			onDelete = "no_action"
		}
		from.ForeignKeys[column] = ForeignKey{Table: m[2], OnDelete: onDelete}
	default:
		err = unsupported(n, line)
	}
	return table, trigger, err
}

func newTable(options string) *SnapshotTable {
	t := &SnapshotTable{
		Columns:     map[string]Column{},
		Indexes:     map[string]SnapshotIndex{},
		ForeignKeys: map[string]ForeignKey{},
		Checks:      map[string]string{},
	}
	if strings.Contains(options, "id: false") {
		return t
	}
	pk := "bigint"
	if strings.Contains(options, "id: :serial") {
		pk = "integer"
	}
	t.PrimaryKey = &pk
	seq := "sequence"
	t.Columns["id"] = Column{Type: pk, Default: &seq}
	return t
}

func parseColumn(typ, options string) (Column, error) {
	def, err := parseDefault(options)
	if err != nil {
		return Column{}, err
	}
	return Column{
		Type:      columnType(typ, options),
		Nullable:  !strings.Contains(options, "null: false"),
		Default:   def,
		Precision: precision(typ, options),
	}, nil
}

func parseIndex(keys, options string) SnapshotIndex {
	ix := SnapshotIndex{
		Unique: strings.Contains(options, "unique: true"),
		Using:  or(option(options, "using"), "btree"),
		Order:  map[string]string{},
	}
	for _, m := range reQuoted.FindAllStringSubmatch(keys, -1) {
		ix.Keys = append(ix.Keys, m[1])
	}
	if !strings.HasPrefix(keys, "[") {
		e := reTrailingOps.ReplaceAllString(strings.Trim(keys, `"`), "")
		ix.Expression = &e
	}
	if w := option(options, "where"); w != "" {
		ix.Where = &w
	}
	switch op := option(options, "opclass"); {
	case op != "":
		ix.Opclass = &op
	default:
		if m := reInlineOps.FindStringSubmatch(keys); m != nil {
			ix.Opclass = &m[1]
		}
	}
	if m := reOrder.FindStringSubmatch(options); m != nil {
		for _, e := range reOrderEntry.FindAllStringSubmatch(m[1], -1) {
			ix.Order[e[1]] = e[2]
		}
	}
	return ix
}

func columnType(typ, options string) string {
	switch typ {
	case "string":
		if l := option(options, "limit"); l != "" {
			return "character varying(" + l + ")"
		}
		return "character varying"
	case "datetime":
		if p := precision("datetime", options); p != nil {
			return fmt.Sprintf("timestamp(%d) without time zone", *p)
		}
		return "timestamp without time zone"
	case "text":
		if strings.Contains(options, "array: true") {
			return "text[]"
		}
		return "text"
	case "float":
		return "double precision"
	case "vector":
		return "vector(" + option(options, "limit") + ")"
	}
	return typ
}

func precision(typ, options string) *int {
	if typ != "datetime" || strings.Contains(options, "precision: nil") {
		return nil
	}
	p := 6
	return &p
}

func parseDefault(options string) (*string, error) {
	if m := reDefaultProc.FindStringSubmatch(options); m != nil {
		return &m[1], nil
	}
	m := reDefault.FindStringSubmatch(options)
	if m == nil {
		return nil, nil //nolint:nilnil // ausência de default é um valor válido
	}
	lit := m[1]
	switch {
	case strings.HasPrefix(lit, `"`):
		s := strings.TrimSuffix(lit[1:], `"`)
		return &s, nil
	case strings.HasPrefix(lit, "{"):
		var v any
		if err := json.Unmarshal([]byte(reHashArrow.ReplaceAllString(lit, `":`)), &v); err != nil {
			return nil, fmt.Errorf("invalid hash default %s: %w", lit, err)
		}
		b, err := json.Marshal(v)
		if err != nil {
			return nil, err
		}
		s := string(b)
		return &s, nil
	}
	return &lit, nil
}

// option devolve o valor de `key: "x"`, `key: :x` ou `key: 1`; vazio quando ausente.
func option(options, key string) string {
	m := regexp.MustCompile(fmt.Sprintf(reStringOption, regexp.QuoteMeta(key))).FindStringSubmatch(options)
	for _, c := range m[min(1, len(m)):] {
		if c != "" {
			return c
		}
	}
	return ""
}

// Nomes de tabela do Rails são plurais em inglês: "inboxes" vira "inbox", não "inboxe".
func singularize(name string) string {
	if strings.HasSuffix(name, "xes") {
		return strings.TrimSuffix(name, "es")
	}
	return strings.TrimSuffix(name, "s")
}

func unsupported(n int, line string) error {
	return fmt.Errorf("unsupported schema instruction at line %d: %s", n, line)
}

func or(v, fallback string) string {
	if v == "" {
		return fallback
	}
	return v
}
