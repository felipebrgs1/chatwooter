defmodule Chatwooter.Conversations.FilterQuery do
  @moduledoc "Bound parameters for Chatwoot's FilterService and lib/filters/filter_keys.yml."
  import Ecto.Query
  alias Chatwooter.Contacts
  alias Chatwooter.Contacts.{Tag, Tagging}
  alias Chatwooter.Conversations.{CustomAttributeFilter, DateFilter, TextFilter}

  @equality ~w(equal_to not_equal_to)
  @presence @equality ++ ~w(is_present is_not_present)
  @fields %{
    "status" => {:status, @equality},
    "priority" => {:priority, @equality},
    "assignee_id" => {:assignee_id, @presence},
    "inbox_id" => {:inbox_id, @presence},
    "team_id" => {:team_id, @presence},
    "campaign_id" => {:campaign_id, @presence},
    "contact_id" => {:contact_id, @equality},
    "display_id" => {:display_id, @equality ++ ~w(contains does_not_contain)}
  }
  @statuses %{
    "open" => :open,
    "resolved" => :resolved,
    "pending" => :pending,
    "snoozed" => :snoozed
  }
  @priorities %{"low" => 0, "medium" => 1, "high" => 2, "urgent" => 3}

  def compile(query, account \\ nil)

  def compile(%{"payload" => conditions}, account)
      when is_list(conditions) and conditions != [] do
    definitions = definitions(account)

    with :ok <- validate_connectors(conditions),
         {:ok, compiled} <- compile_conditions(conditions, definitions) do
      {:ok, combine(compiled)}
    end
  end

  def compile(_query, _account), do: {:error, :invalid_payload}

  def standard_attribute?(key),
    do:
      Map.has_key?(@fields, key) or
        key in ~w(labels created_at last_activity_at browser_language conversation_language referer mail_subject)

  defp definitions(nil), do: %{}

  defp definitions(account) do
    account
    |> Contacts.list_custom_attribute_definitions()
    |> Enum.filter(&(&1.attribute_model == :conversation_attribute))
    |> Map.new(&{&1.attribute_key, &1})
  end

  defp validate_connectors(conditions) do
    {body, [last]} = Enum.split(conditions, -1)

    if is_map(last) and is_nil(last["query_operator"]) and
         Enum.all?(body, &(is_map(&1) and &1["query_operator"] in ~w(and or))) do
      :ok
    else
      {:error, :invalid_query_operator}
    end
  end

  defp compile_conditions(conditions, definitions) do
    Enum.reduce_while(conditions, {:ok, []}, fn condition, {:ok, acc} ->
      case compile_condition(condition, definitions) do
        {:ok, predicate} -> {:cont, {:ok, acc ++ [{predicate, condition["query_operator"]}]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp compile_condition(row, definitions) do
    case compile_condition(row) do
      {:error, :invalid_attribute} -> CustomAttributeFilter.compile(row, definitions)
      result -> result
    end
  end

  # SQL gives AND precedence over OR. Build the same groups before adding the account WHERE.
  defp combine(compiled) do
    {groups, group} =
      Enum.reduce(compiled, {[], dynamic(true)}, fn {predicate, join}, {groups, group} ->
        group = dynamic(^group and ^predicate)
        if join == "or", do: {[group | groups], dynamic(true)}, else: {groups, group}
      end)

    Enum.reduce(groups, group, fn predicate, acc -> dynamic(^acc or ^predicate) end)
  end

  defp compile_condition(%{"attribute_key" => key} = row)
       when key in ~w(created_at last_activity_at),
       do: DateFilter.compile(row)

  defp compile_condition(%{
         "attribute_key" => key,
         "filter_operator" => operator,
         "values" => values
       })
       when key in ~w(browser_language conversation_language referer mail_subject) do
    operators =
      if key in ~w(referer mail_subject),
        do: @equality ++ ~w(contains does_not_contain),
        else: @equality

    if operator in operators do
      expression = dynamic([c], fragment("? ->> ?", c.additional_attributes, ^key))
      TextFilter.compile(expression, operator, values)
    else
      {:error, :invalid_filter_operator}
    end
  end

  defp compile_condition(%{
         "attribute_key" => "labels",
         "filter_operator" => operator,
         "values" => values
       })
       when operator in @presence and is_list(values) do
    if operator in ~w(is_present is_not_present) or
         (values != [] and Enum.all?(values, &is_binary/1)) do
      tags =
        from tg in Tagging,
          join: tag in Tag,
          on: tag.id == tg.tag_id,
          where: tg.taggable_type == "Conversation",
          select: tg.taggable_id

      tags =
        if operator in @equality, do: where(tags, [_tg, tag], tag.name in ^values), else: tags

      predicate = dynamic([c], c.id in subquery(tags))

      {:ok,
       if(operator in ~w(not_equal_to is_not_present),
         do: dynamic(not (^predicate)),
         else: predicate
       )}
    else
      {:error, :invalid_values}
    end
  end

  defp compile_condition(%{
         "attribute_key" => key,
         "filter_operator" => operator,
         "values" => values
       })
       when is_list(values) do
    case Map.get(@fields, key) do
      {field, operators} ->
        if operator in operators,
          do: field_condition(field, operator, values),
          else: {:error, :invalid_filter_operator}

      nil ->
        {:error, :invalid_attribute}
    end
  end

  defp compile_condition(_condition), do: {:error, :invalid_condition}

  defp field_condition(:assignee_id, "is_present", _values),
    do: {:ok, dynamic([c], not is_nil(c.assignee_id) or not is_nil(c.assignee_agent_bot_id))}

  defp field_condition(:assignee_id, "is_not_present", _values),
    do: {:ok, dynamic([c], is_nil(c.assignee_id) and is_nil(c.assignee_agent_bot_id))}

  defp field_condition(field, "is_present", _values),
    do: {:ok, dynamic([c], not is_nil(field(c, ^field)))}

  defp field_condition(field, "is_not_present", _values),
    do: {:ok, dynamic([c], is_nil(field(c, ^field)))}

  defp field_condition(:display_id, operator, values)
       when operator in ~w(contains does_not_contain) and values != [] do
    if Enum.all?(values, &(is_binary(&1) or is_integer(&1))) do
      match =
        Enum.reduce(values, dynamic(false), fn value, acc ->
          pattern = "%#{value}%"
          dynamic([c], ^acc or ilike(fragment("?::text", c.display_id), ^pattern))
        end)

      {:ok, if(operator == "contains", do: match, else: dynamic(not (^match)))}
    else
      {:error, :invalid_values}
    end
  end

  defp field_condition(field, operator, values) when operator in @equality and values != [] do
    with {:ok, values} <- cast_values(field, values) do
      predicate = dynamic([c], field(c, ^field) in ^values)
      {:ok, if(operator == "equal_to", do: predicate, else: dynamic(not (^predicate)))}
    end
  end

  defp field_condition(_field, _operator, _values), do: {:error, :invalid_values}

  defp cast_values(:status, values) do
    if "all" in values do
      if Enum.all?(values, &(&1 == "all" or Map.has_key?(@statuses, &1))),
        do: {:ok, Map.values(@statuses)},
        else: {:error, :invalid_values}
    else
      cast_enum(values, @statuses)
    end
  end

  defp cast_values(:priority, values), do: cast_enum(values, @priorities)

  defp cast_values(_field, values) do
    results = Enum.map(values, &Ecto.Type.cast(:integer, &1))

    if Enum.all?(results, &match?({:ok, value} when is_integer(value), &1)),
      do: {:ok, Enum.map(results, &elem(&1, 1))},
      else: {:error, :invalid_values}
  end

  defp cast_enum(values, mapping) do
    if Enum.all?(values, &Map.has_key?(mapping, &1)),
      do: {:ok, Enum.map(values, &Map.fetch!(mapping, &1))},
      else: {:error, :invalid_values}
  end
end
