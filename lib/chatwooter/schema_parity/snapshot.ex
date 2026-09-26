defmodule Chatwooter.SchemaParity.Snapshot do
  @moduledoc """
  Reads the pinned Rails schema as data; never evaluates Ruby. Unknown statements fail closed.
  A Rails schema does not record model enum mappings or migration-only checks/triggers.
  """

  @types ~w(string text integer bigint boolean datetime date float json jsonb uuid vector)

  def load!(path) do
    path
    |> File.stream!()
    |> Enum.with_index(1)
    |> Enum.reduce(
      %{version: nil, extensions: [], tables: %{}, current: nil, triggers: %{}, trigger: nil},
      fn {line, number}, state -> parse(String.trim_trailing(line), number, state) end
    )
    |> finish!()
  end

  defp parse(line, _number, state)
       when line in ["", "end"] and state.current == nil and state.trigger == nil,
       do: state

  defp parse(line, number, %{trigger: name} = state) when not is_nil(name) do
    cond do
      match = Regex.run(~r/^      on\("([^"]+)"\)\.$/, line) ->
        update_in(state, [:triggers], &Map.put(&1, name, Enum.at(match, 1)))

      line == "  end" ->
        %{state | trigger: nil}

      String.starts_with?(line, "      ") or String.starts_with?(line, "    ") ->
        state

      true ->
        unsupported!(number, line)
    end
  end

  defp parse(line, number, %{current: name} = state) when not is_nil(name) do
    cond do
      line == "  end" ->
        %{state | current: nil}

      match = Regex.run(~r/^    t.check_constraint "([^"]+)", name: "([^"]+)"$/, line) ->
        [_, expression, check_name] = match
        update_in(state, [:tables, name, :checks], &Map.put(&1, check_name, expression))

      match = Regex.run(~r/^    t.index (.+), name: "([^"]+)"(.*)$/, line) ->
        [_, keys, index_name, options] = match

        update_in(
          state,
          [:tables, name, :indexes],
          &Map.put(&1, index_name, index(keys, options))
        )

      match = Regex.run(~r/^    t\.(\w+) "([^"]+)"(.*)$/, line) ->
        [_, type, column_name, options] = match
        if type not in @types, do: unsupported!(number, line)

        update_in(
          state,
          [:tables, name, :columns],
          &Map.put(&1, column_name, column(type, options))
        )

      true ->
        unsupported!(number, line)
    end
  end

  defp parse(line, number, state) do
    if String.trim(line) == "" or String.starts_with?(String.trim_leading(line), "#") do
      state
    else
      parse_statement(line, number, state)
    end
  end

  defp parse_statement(line, number, state) do
    cond do
      match = Regex.run(~r/^ActiveRecord::Schema\[.*\]\.define\(version: ([\d_]+)\) do$/, line) ->
        %{state | version: Enum.at(match, 1)}

      match = Regex.run(~r/^  create_trigger\("([^"]+)".*$/, line) ->
        %{state | trigger: Enum.at(match, 1)}

      match = Regex.run(~r/^  enable_extension "([^"]+)"$/, line) ->
        %{state | extensions: state.extensions ++ [Enum.at(match, 1)]}

      match = Regex.run(~r/^  create_table "([^"]+)"(.*) do \|t\|$/, line) ->
        [_, name, options] = match
        %{state | current: name, tables: Map.put(state.tables, name, table(options))}

      match = Regex.run(~r/^  add_foreign_key "([^"]+)", "([^"]+)"(.*)$/, line) ->
        [_, from, to, options] = match
        column = option(options, "column") || "#{String.trim_trailing(to, "s")}_id"
        fk = %{table: to, on_delete: option(options, "on_delete") || "no_action"}
        update_in(state, [:tables, from, :foreign_keys], &Map.put(&1, column, fk))

      true ->
        unsupported!(number, line)
    end
  end

  defp table(options) do
    pk =
      if String.contains?(options, "id: false"),
        do: nil,
        else: if(String.contains?(options, "id: :serial"), do: "integer", else: "bigint")

    columns =
      if pk,
        do: %{"id" => %{type: pk, nullable: false, default: "sequence", precision: nil}},
        else: %{}

    %{primary_key: pk, columns: columns, indexes: %{}, foreign_keys: %{}, checks: %{}}
  end

  defp column(type, options) do
    %{
      type: column_type(type, options),
      nullable: not String.contains?(options, "null: false"),
      default: default(options),
      precision: precision(type, options)
    }
  end

  defp index(keys, options) do
    %{
      keys: Regex.scan(~r/"([^"]+)"/, keys) |> Enum.map(&Enum.at(&1, 1)),
      expression: if(String.starts_with?(keys, "["), do: nil, else: keys),
      unique: String.contains?(options, "unique: true"),
      using: option(options, "using") || "btree",
      where: option(options, "where"),
      opclass: option(options, "opclass"),
      order:
        case Regex.run(~r/order: \{ \w+: "([^"]+)" \}/, options) do
          [_, value] -> value
          _ -> nil
        end
    }
  end

  defp finish!(%{version: nil}), do: raise(ArgumentError, "missing Rails schema version")

  defp finish!(%{current: name}) when not is_nil(name),
    do: raise(ArgumentError, "unterminated table #{name}")

  defp finish!(%{trigger: name}) when not is_nil(name),
    do: raise(ArgumentError, "unterminated trigger #{name}")

  defp finish!(state), do: state |> Map.delete(:current) |> Map.delete(:trigger)

  defp unsupported!(number, line),
    do: raise(ArgumentError, "unsupported schema instruction at line #{number}: #{line}")

  defp column_type("string", options),
    do:
      if(l = option(options, "limit"),
        do: "character varying(#{l})",
        else: "character varying(255)"
      )

  defp column_type("datetime", options) do
    case precision("datetime", options) do
      nil -> "timestamp without time zone"
      value -> "timestamp(#{value}) without time zone"
    end
  end

  defp column_type("text", options),
    do: if(String.contains?(options, "array: true"), do: "text[]", else: "text")

  defp column_type("float", _), do: "double precision"
  defp column_type("vector", options), do: "vector(#{option(options, "limit")})"
  defp column_type(type, _), do: type

  defp precision("datetime", options),
    do: if(String.contains?(options, "precision: nil"), do: nil, else: 6)

  defp precision(_, _), do: nil

  defp default(options) do
    case Regex.run(~r/default: -> \{ "([^"]+)" \}/, options) do
      [_, expression] ->
        expression

      _ ->
        case Regex.run(~r/default: ("[^"]*"|\{\}|\[\]|true|false|-?\d+)/, options) do
          [_, "\"" <> string] -> String.trim_trailing(string, "\"")
          [_, literal] -> literal
          _ -> nil
        end
    end
  end

  defp option(options, key) do
    case Regex.run(
           Regex.compile!("(?:^|, )#{key}: (?:\"([^\"]*)\"|:([a-z_]+)|(-?\\d+))"),
           options
         ) do
      nil -> nil
      [_whole | captures] -> Enum.find(captures, &(&1 != ""))
    end
  end
end
