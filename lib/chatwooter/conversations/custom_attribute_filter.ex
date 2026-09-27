defmodule Chatwooter.Conversations.CustomAttributeFilter do
  @moduledoc "Typed predicates from Chatwoot's filters/custom_attribute_filter_helper.rb."
  import Ecto.Query
  alias Chatwooter.Conversations.TextFilter

  def compile(
        %{"attribute_key" => key, "filter_operator" => operator, "values" => values} = row,
        definitions
      )
      when is_list(values) do
    with %{attribute_display_type: type} <- Map.get(definitions, key),
         true <- row["custom_attribute_type"] in [nil, "conversation_attribute"] do
      compile_type(key, type, operator, values)
    else
      _ -> {:error, :invalid_attribute}
    end
  end

  def compile(_row, _definitions), do: {:error, :invalid_condition}

  defp compile_type(key, type, operator, values) do
    expression = expression(key, type)

    if expression do
      operation(expression, type, operator, values)
    else
      {:error, :invalid_attribute_type}
    end
  end

  defp expression(key, type) when type in [:text, :list, :link],
    do: dynamic([c], fragment("LOWER(? ->> ?)", c.custom_attributes, ^key))

  # Malformed scalar values in restored JSON are treated as absent instead of crashing the list.
  defp expression(key, :number),
    do:
      dynamic(
        [c],
        fragment(
          "CASE WHEN pg_input_is_valid(? ->> ?, 'numeric') THEN (? ->> ?)::numeric END",
          c.custom_attributes,
          ^key,
          c.custom_attributes,
          ^key
        )
      )

  defp expression(key, :date),
    do:
      dynamic(
        [c],
        fragment(
          "CASE WHEN pg_input_is_valid(? ->> ?, 'date') THEN (? ->> ?)::date END",
          c.custom_attributes,
          ^key,
          c.custom_attributes,
          ^key
        )
      )

  defp expression(key, :checkbox),
    do:
      dynamic(
        [c],
        fragment(
          "CASE WHEN pg_input_is_valid(? ->> ?, 'boolean') THEN (? ->> ?)::boolean END",
          c.custom_attributes,
          ^key,
          c.custom_attributes,
          ^key
        )
      )

  defp expression(_key, _type), do: nil

  defp operation(expression, _type, "is_present", _values),
    do: {:ok, dynamic(not is_nil(^expression))}

  defp operation(expression, _type, "is_not_present", _values),
    do: {:ok, dynamic(is_nil(^expression))}

  defp operation(expression, type, operator, values) when type in [:text, :list, :link] do
    if values != [] && Enum.all?(values, &is_binary/1) do
      # FilterService.string_filter_values uses the first value for custom text equality.
      values = if operator in ~w(equal_to not_equal_to), do: [hd(values)], else: values
      result = TextFilter.compile(expression, operator, Enum.map(values, &String.downcase/1))
      include_missing(result, expression, operator)
    else
      {:error, :invalid_values}
    end
  end

  defp operation(expression, :date, "days_before", [value]) do
    case Ecto.Type.cast(:integer, value) do
      {:ok, days} when days in 1..998 ->
        date = Date.add(Date.utc_today(), -days)
        {:ok, dynamic(^expression < ^date)}

      _ ->
        {:error, :invalid_values}
    end
  end

  defp operation(expression, type, operator, values)
       when operator in ~w(equal_to not_equal_to is_greater_than is_less_than) do
    with {:ok, cast} <- cast_values(type, values),
         {:ok, predicate} <- compare(expression, operator, cast) do
      include_missing({:ok, predicate}, expression, operator)
    end
  end

  defp operation(_expression, _type, _operator, _values), do: {:error, :invalid_filter_operator}

  defp cast_values(type, values) when values != [] do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case cast_value(type, value) do
        {:ok, cast} -> {:cont, {:ok, acc ++ [cast]}}
        _ -> {:halt, {:error, :invalid_values}}
      end
    end)
  end

  defp cast_values(_type, _values), do: {:error, :invalid_values}

  defp cast_value(:number, value) do
    case Ecto.Type.cast(:decimal, value) do
      {:ok, %Decimal{exp: exp} = decimal} when is_integer(exp) -> {:ok, decimal}
      _ -> {:error, :invalid_values}
    end
  end

  defp cast_value(:date, value) when is_binary(value), do: Date.from_iso8601(value)

  defp cast_value(:checkbox, value) when value in [true, false, "true", "false"],
    do: Ecto.Type.cast(:boolean, value)

  defp cast_value(_type, _value), do: {:error, :invalid_values}

  defp compare(expression, "equal_to", values), do: {:ok, dynamic(^expression in ^values)}
  defp compare(expression, "not_equal_to", values), do: {:ok, dynamic(^expression not in ^values)}
  defp compare(expression, "is_greater_than", [value]), do: {:ok, dynamic(^expression > ^value)}
  defp compare(expression, "is_less_than", [value]), do: {:ok, dynamic(^expression < ^value)}
  defp compare(_expression, _operator, _values), do: {:error, :invalid_values}

  defp include_missing({:ok, predicate}, expression, "not_equal_to"),
    do: {:ok, dynamic(^predicate or is_nil(^expression))}

  defp include_missing(result, _expression, _operator), do: result
end
