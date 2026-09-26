defmodule Chatwooter.SchemaParity do
  @moduledoc """
  Structural comparison of a migrated PostgreSQL database against the pinned Chatwoot snapshot.
  Names are part of the contract; a transformed field is reported, never silently accepted.
  """

  alias Chatwooter.SchemaParity.Snapshot

  @columns """
  SELECT c.relname, a.attname, pg_catalog.format_type(a.atttypid, a.atttypmod),
         NOT a.attnotnull, pg_get_expr(d.adbin, d.adrelid),
         CASE WHEN a.atttypid = 'timestamp'::regtype THEN a.atttypmod ELSE NULL END
  FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
  JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
  LEFT JOIN pg_attrdef d ON d.adrelid = c.oid AND d.adnum = a.attnum
  WHERE ns.nspname = current_schema() AND c.relkind IN ('r', 'p')
  ORDER BY c.relname, a.attnum
  """
  @indexes """
  SELECT c.relname, ic.relname, i.indisunique, am.amname,
         pg_get_expr(i.indpred, i.indrelid),
         ARRAY(SELECT pg_get_indexdef(i.indexrelid, n, true)
               FROM generate_series(1, i.indnkeyatts) AS n), i.indisprimary
  FROM pg_index i JOIN pg_class c ON c.oid = i.indrelid
  JOIN pg_namespace ns ON ns.oid = c.relnamespace
  JOIN pg_class ic ON ic.oid = i.indexrelid JOIN pg_am am ON am.oid = ic.relam
  WHERE ns.nspname = current_schema()
  """
  @triggers """
  SELECT tg.tgname, c.relname
  FROM pg_trigger tg JOIN pg_class c ON c.oid = tg.tgrelid
  JOIN pg_namespace ns ON ns.oid = c.relnamespace
  WHERE ns.nspname = current_schema() AND NOT tg.tgisinternal
  """
  @checks """
  SELECT c.relname, con.conname, pg_get_constraintdef(con.oid)
  FROM pg_constraint con JOIN pg_class c ON c.oid = con.conrelid
  JOIN pg_namespace ns ON ns.oid = c.relnamespace
  WHERE ns.nspname = current_schema() AND con.contype = 'c'
  """
  @foreign_keys """
  SELECT c.relname, a.attname, target.relname, f.confdeltype
  FROM pg_constraint f JOIN pg_class c ON c.oid = f.conrelid
  JOIN pg_namespace ns ON ns.oid = c.relnamespace
  JOIN pg_class target ON target.oid = f.confrelid
  JOIN LATERAL unnest(f.conkey) AS key(attnum) ON true
  JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = key.attnum
  WHERE ns.nspname = current_schema() AND f.contype = 'f'
  """

  def compare(repo, path) do
    expected = Snapshot.load!(path)
    actual = catalog(repo)
    upstream = Map.keys(expected.tables)
    local = Map.keys(actual.tables)

    tables =
      for name <- upstream, into: %{} do
        source = expected.tables[name]

        destination =
          Map.get(actual.tables, name, %{
            primary_key: nil,
            columns: %{},
            indexes: %{},
            foreign_keys: %{},
            checks: %{}
          })

        {name,
         %{
           status: if(Map.has_key?(actual.tables, name), do: :present, else: :missing),
           primary_key: diff_value(pk(source.primary_key), destination.primary_key),
           columns: compare_named(source.columns, destination.columns, &compare_column/2),
           missing_columns:
             (Map.keys(source.columns) -- Map.keys(destination.columns)) |> Enum.sort(),
           local_columns:
             (Map.keys(destination.columns) -- Map.keys(source.columns)) |> Enum.sort(),
           indexes: compare_named(source.indexes, destination.indexes, &compare_index/2),
           foreign_keys:
             compare_named(source.foreign_keys, destination.foreign_keys, &(&1 == &2)),
           checks:
             compare_named(
               source.checks,
               destination.checks,
               &(normalize_sql(&1) == normalize_sql(&2))
             )
         }}
      end

    missing = Enum.sort(upstream -- local)
    extra = Enum.sort(local -- upstream)

    extension_diffs =
      compare_named(
        Map.new(expected.extensions, &{&1, true}),
        Map.new(actual.extensions, &{&1, true}),
        &(&1 == &2)
      )

    trigger_diffs = compare_named(expected.triggers, actual.triggers, &(&1 == &2))
    # Trigger presence cannot prove Rails trigger bodies match PostgreSQL functions.
    trigger_diffs =
      Map.new(trigger_diffs, fn {name, diff} ->
        {name, if(diff.status == :equal, do: %{diff | status: :body_unverified}, else: diff)}
      end)

    parity? =
      missing == [] and Enum.all?(tables, fn {_, t} -> table_equal?(t) end) and
        Enum.all?(extension_diffs, fn {_, d} -> d.status == :equal end) and trigger_diffs == %{}

    %{
      version: expected.version,
      limitations: [
        "Enums Rails, transforms de importacao e dados nao constam do schema.rb",
        "Corpos das funcoes de triggers nao sao verificados pelo catalogo",
        "Indices sao comparados por nome, chaves, unicidade, metodo e predicado; revisar opclasses e ordens especiais"
      ],
      extensions: extension_diffs,
      triggers: trigger_diffs,
      missing_tables: missing,
      local_tables: extra,
      tables: tables,
      summary: %{
        upstream_tables: length(upstream),
        local_tables: length(local),
        missing_tables: length(missing),
        compared_tables: length(upstream) - length(missing),
        parity?: parity?
      }
    }
  end

  defp pk(nil), do: nil
  defp pk(type), do: %{column: "id", type: type}

  defp table_equal?(table) do
    table.primary_key.status == :equal and table.missing_columns == [] and
      table.local_columns == [] and
      Enum.all?([table.columns, table.indexes, table.foreign_keys, table.checks], fn entries ->
        Enum.all?(entries, fn {_, diff} -> diff.status == :equal end)
      end)
  end

  defp compare_named(expected, actual, comparison) do
    Map.new((Map.keys(expected) ++ Map.keys(actual)) |> Enum.uniq(), fn name ->
      {name,
       case {Map.fetch(expected, name), Map.fetch(actual, name)} do
         {{:ok, source}, {:ok, destination}} ->
           diff_value(source, destination, comparison)

         {{:ok, source}, :error} ->
           %{status: :missing, expected: source, actual: nil}

         {:error, {:ok, destination}} ->
           %{status: :local_only, expected: nil, actual: destination}
       end}
    end)
  end

  defp diff_value(expected, actual, comparison \\ &(&1 == &2)) do
    %{
      status: if(comparison.(expected, actual), do: :equal, else: :different),
      expected: expected,
      actual: actual
    }
  end

  defp compare_column(expected, actual) do
    expected.type == actual.type and expected.nullable == actual.nullable and
      expected.precision == actual.precision and
      normalize_default(expected.default) == normalize_default(actual.default)
  end

  defp normalize_default(nil), do: nil
  defp normalize_default(value) when value in ["{}", "[]"], do: value

  defp normalize_default(value) do
    if String.starts_with?(value, "nextval(") do
      "sequence"
    else
      value
      |> String.replace(~r/::[\w\s\[\]]+$/, "")
      |> String.trim("'")
      |> String.replace(~r/^\('(.+)'\)$/, "\\1")
    end
  end

  defp compare_index(expected, actual) do
    expected.unique == actual.unique and expected.using == actual.using and
      normalize_sql(expected.where) == normalize_sql(actual.where) and
      if(expected.expression,
        do: normalize_sql(expected.expression) == normalize_sql(Enum.join(actual.keys, ", ")),
        else: Enum.map(expected.keys, &normalize_sql/1) == Enum.map(actual.keys, &normalize_sql/1)
      ) and
      (is_nil(expected.opclass) or Enum.any?(actual.keys, &String.contains?(&1, expected.opclass))) and
      (is_nil(expected.order) or Enum.any?(actual.keys, &String.contains?(&1, expected.order)))
  end

  defp normalize_sql(nil), do: nil
  defp normalize_sql(sql), do: sql |> String.downcase() |> String.replace(~r/\s+/, "")

  defp catalog(repo) do
    tables =
      repo.query!(@columns).rows
      |> Enum.reduce(%{}, fn [table, column, type, nullable, default, typmod], acc ->
        entry = %{
          type: type,
          nullable: nullable,
          default: default,
          precision: if(typmod == -1, do: nil, else: typmod)
        }

        update_in(
          acc,
          [
            Access.key(table, %{
              columns: %{},
              indexes: %{},
              foreign_keys: %{},
              checks: %{},
              primary_key: nil
            }),
            :columns
          ],
          &Map.put(&1, column, entry)
        )
      end)

    tables =
      Enum.reduce(repo.query!(@indexes).rows, tables, fn [
                                                           table,
                                                           name,
                                                           unique,
                                                           using,
                                                           where,
                                                           keys,
                                                           primary
                                                         ],
                                                         acc ->
        if primary do
          put_in(acc, [table, :primary_key], %{
            column: hd(keys),
            type: acc[table].columns[hd(keys)].type
          })
        else
          put_in(acc, [table, :indexes, name], %{
            unique: unique,
            using: using,
            where: where,
            keys: keys
          })
        end
      end)

    tables =
      Enum.reduce(repo.query!(@foreign_keys).rows, tables, fn [table, column, target, delete],
                                                              acc ->
        action =
          case delete do
            "c" -> "cascade"
            "n" -> "nullify"
            "r" -> "restrict"
            "d" -> "set_default"
            "a" -> "no_action"
            other -> other
          end

        put_in(acc, [table, :foreign_keys, column], %{table: target, on_delete: action})
      end)

    tables =
      Enum.reduce(repo.query!(@checks).rows, tables, fn [table, name, expression], acc ->
        put_in(acc, [table, :checks, name], expression)
      end)

    extensions = repo.query!("SELECT extname FROM pg_extension").rows |> Enum.map(&hd/1)
    triggers = repo.query!(@triggers).rows |> Map.new(fn [name, table] -> {name, table} end)
    %{tables: tables, extensions: extensions, triggers: triggers}
  end
end
