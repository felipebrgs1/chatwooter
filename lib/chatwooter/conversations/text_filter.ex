defmodule Chatwooter.Conversations.TextFilter do
  @moduledoc "Bound text comparisons matching Chatwoot FilterService's equality and ILIKE operations."
  import Ecto.Query

  def compile(expression, operator, values) when is_list(values) and values != [] do
    if Enum.all?(values, &is_binary/1) do
      predicate(expression, operator, values)
    else
      {:error, :invalid_values}
    end
  end

  def compile(_expression, _operator, _values), do: {:error, :invalid_values}

  defp predicate(expression, "equal_to", values), do: {:ok, dynamic(^expression in ^values)}

  defp predicate(expression, "not_equal_to", values),
    do: {:ok, dynamic(^expression not in ^values)}

  defp predicate(expression, operator, values) when operator in ~w(contains does_not_contain) do
    match =
      Enum.reduce(values, dynamic(false), fn value, acc ->
        pattern = "%#{String.trim(value)}%"
        dynamic(^acc or ilike(^expression, ^pattern))
      end)

    {:ok, if(operator == "contains", do: match, else: dynamic(not (^match)))}
  end

  defp predicate(_expression, _operator, _values), do: {:error, :invalid_filter_operator}
end
