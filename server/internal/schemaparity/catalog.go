package schemaparity

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

type PrimaryKey struct {
	Column string
	Type   string
}

type CatalogIndex struct {
	Unique    bool
	Using     string
	Where     *string
	Keys      []string
	Opclasses []string
	Orders    []string // "" quando o método não é btree
}

type CatalogTable struct {
	PrimaryKey  *PrimaryKey
	Columns     map[string]Column
	Indexes     map[string]CatalogIndex
	ForeignKeys map[string]ForeignKey
	Checks      map[string]string
}

type Catalog struct {
	Tables     map[string]*CatalogTable
	Extensions []string
	Triggers   map[string]Trigger
}

const columnsSQL = `
SELECT c.relname, a.attname, pg_catalog.format_type(a.atttypid, a.atttypmod),
       NOT a.attnotnull, pg_get_expr(d.adbin, d.adrelid),
       CASE WHEN a.atttypid = 'timestamp'::regtype THEN a.atttypmod ELSE NULL END
FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
LEFT JOIN pg_attrdef d ON d.adrelid = c.oid AND d.adnum = a.attnum
WHERE ns.nspname = current_schema() AND c.relkind IN ('r', 'p')
ORDER BY c.relname, a.attnum`

const indexesSQL = `
SELECT c.relname, ic.relname, i.indisunique, am.amname,
       pg_get_expr(i.indpred, i.indrelid),
       ARRAY(SELECT pg_get_indexdef(i.indexrelid, n, true)
             FROM generate_series(1, i.indnkeyatts) AS n), i.indisprimary,
       ARRAY(SELECT opc.opcname FROM unnest(i.indclass::oid[]) WITH ORDINALITY AS cls(oid, pos)
             JOIN pg_opclass opc ON opc.oid = cls.oid ORDER BY cls.pos),
       ARRAY(SELECT CASE WHEN am.amname = 'btree' THEN
         (CASE WHEN (opt.value & 1) = 1 THEN 'DESC' ELSE 'ASC' END) ||
         (CASE WHEN (opt.value & 2) = 2 THEN ' NULLS FIRST' ELSE ' NULLS LAST' END)
         ELSE '' END
         FROM unnest(i.indoption::smallint[]) WITH ORDINALITY AS opt(value, pos)
         ORDER BY opt.pos)
FROM pg_index i JOIN pg_class c ON c.oid = i.indrelid
JOIN pg_namespace ns ON ns.oid = c.relnamespace
JOIN pg_class ic ON ic.oid = i.indexrelid JOIN pg_am am ON am.oid = ic.relam
WHERE ns.nspname = current_schema()`

const foreignKeysSQL = `
SELECT c.relname, a.attname, target.relname, f.confdeltype::text
FROM pg_constraint f JOIN pg_class c ON c.oid = f.conrelid
JOIN pg_namespace ns ON ns.oid = c.relnamespace
JOIN pg_class target ON target.oid = f.confrelid
JOIN LATERAL unnest(f.conkey) AS key(attnum) ON true
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = key.attnum
WHERE ns.nspname = current_schema() AND f.contype = 'f'`

const checksSQL = `
SELECT c.relname, con.conname, pg_get_constraintdef(con.oid)
FROM pg_constraint con JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace ns ON ns.oid = c.relnamespace
WHERE ns.nspname = current_schema() AND con.contype = 'c'`

// tgtype: 1 ROW, 2 BEFORE, 4 INSERT, 8 DELETE, 16 UPDATE, 32 TRUNCATE, 64 INSTEAD OF.
const triggersSQL = `
SELECT tg.tgname, c.relname,
       CASE WHEN tg.tgtype & 2 <> 0 THEN 'BEFORE' WHEN tg.tgtype & 64 <> 0 THEN 'INSTEAD OF' ELSE 'AFTER' END,
       array_to_string(ARRAY[
         CASE WHEN tg.tgtype & 8 <> 0 THEN 'DELETE' END, CASE WHEN tg.tgtype & 4 <> 0 THEN 'INSERT' END,
         CASE WHEN tg.tgtype & 32 <> 0 THEN 'TRUNCATE' END, CASE WHEN tg.tgtype & 16 <> 0 THEN 'UPDATE' END
       ], ' OR '),
       CASE WHEN tg.tgtype & 1 <> 0 THEN 'ROW' ELSE 'STATEMENT' END,
       p.proname, p.prosrc
FROM pg_trigger tg JOIN pg_class c ON c.oid = tg.tgrelid
JOIN pg_namespace ns ON ns.oid = c.relnamespace
JOIN pg_proc p ON p.oid = tg.tgfoid
WHERE ns.nspname = current_schema() AND NOT tg.tgisinternal`

var deleteActions = map[string]string{
	"c": "cascade", "n": "nullify", "r": "restrict", "d": "set_default", "a": "no_action",
}

// LoadCatalog lê o catálogo físico do schema corrente.
func LoadCatalog(ctx context.Context, pool *pgxpool.Pool) (*Catalog, error) {
	cat := &Catalog{Tables: map[string]*CatalogTable{}, Triggers: map[string]Trigger{}}

	if err := loadColumns(ctx, pool, cat); err != nil {
		return nil, fmt.Errorf("columns: %w", err)
	}
	if err := loadIndexes(ctx, pool, cat); err != nil {
		return nil, fmt.Errorf("indexes: %w", err)
	}
	if err := loadForeignKeys(ctx, pool, cat); err != nil {
		return nil, fmt.Errorf("foreign keys: %w", err)
	}
	if err := loadChecks(ctx, pool, cat); err != nil {
		return nil, fmt.Errorf("checks: %w", err)
	}

	rows, err := pool.Query(ctx, "SELECT extname FROM pg_extension")
	if err != nil {
		return nil, err
	}
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		cat.Extensions = append(cat.Extensions, name)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}

	rows, err = pool.Query(ctx, triggersSQL)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var name string
		var tr Trigger
		if err := rows.Scan(&name, &tr.Table, &tr.Timing, &tr.Events, &tr.ForEach, &tr.Function, &tr.Body); err != nil {
			return nil, err
		}
		cat.Triggers[name] = tr
	}
	return cat, rows.Err()
}

func (c *Catalog) table(name string) *CatalogTable {
	t, ok := c.Tables[name]
	if !ok {
		t = &CatalogTable{
			Columns:     map[string]Column{},
			Indexes:     map[string]CatalogIndex{},
			ForeignKeys: map[string]ForeignKey{},
			Checks:      map[string]string{},
		}
		c.Tables[name] = t
	}
	return t
}

func loadColumns(ctx context.Context, pool *pgxpool.Pool, cat *Catalog) error {
	rows, err := pool.Query(ctx, columnsSQL)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var table, name string
		var col Column
		var typmod *int32
		if err := rows.Scan(&table, &name, &col.Type, &col.Nullable, &col.Default, &typmod); err != nil {
			return err
		}
		if typmod != nil && *typmod != -1 {
			p := int(*typmod)
			col.Precision = &p
		}
		cat.table(table).Columns[name] = col
	}
	return rows.Err()
}

func loadIndexes(ctx context.Context, pool *pgxpool.Pool, cat *Catalog) error {
	rows, err := pool.Query(ctx, indexesSQL)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var table, name string
		var primary bool
		var ix CatalogIndex
		if err := rows.Scan(&table, &name, &ix.Unique, &ix.Using, &ix.Where, &ix.Keys, &primary, &ix.Opclasses, &ix.Orders); err != nil {
			return err
		}
		t := cat.table(table)
		if primary {
			t.PrimaryKey = &PrimaryKey{Column: ix.Keys[0], Type: t.Columns[ix.Keys[0]].Type}
			continue
		}
		t.Indexes[name] = ix
	}
	return rows.Err()
}

func loadForeignKeys(ctx context.Context, pool *pgxpool.Pool, cat *Catalog) error {
	rows, err := pool.Query(ctx, foreignKeysSQL)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var table, column, target, action string
		if err := rows.Scan(&table, &column, &target, &action); err != nil {
			return err
		}
		if named, ok := deleteActions[action]; ok {
			action = named
		}
		cat.table(table).ForeignKeys[column] = ForeignKey{Table: target, OnDelete: action}
	}
	return rows.Err()
}

func loadChecks(ctx context.Context, pool *pgxpool.Pool, cat *Catalog) error {
	rows, err := pool.Query(ctx, checksSQL)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var table, name, expr string
		if err := rows.Scan(&table, &name, &expr); err != nil {
			return err
		}
		cat.table(table).Checks[name] = expr
	}
	return rows.Err()
}
