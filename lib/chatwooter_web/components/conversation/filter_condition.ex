defmodule ChatwooterWeb.Components.Conversation.FilterCondition do
  @moduledoc "Port of components-next/filter/ConditionRow.vue."
  use ChatwooterWeb, :component
  import ChatwooterWeb.Components.Conversation.FilterSelect
  import ChatwooterWeb.Components.Conversation.FilterMultiSelect

  @operators [
    {"equal_to", "Equal to"},
    {"not_equal_to", "Not equal to"},
    {"is_present", "Is present"},
    {"is_not_present", "Is not present"},
    {"contains", "Contains"},
    {"does_not_contain", "Does not contain"},
    {"is_greater_than", "Is greater than"},
    {"is_less_than", "Is lesser than"},
    {"days_before", "Is x days before"}
  ]

  attr :row, Phoenix.HTML.Form, required: true
  attr :previous, :any, default: nil
  attr :index, :integer, required: true
  attr :attributes, :list, required: true
  attr :definition, :any, default: nil
  attr :labels, :list, default: []
  attr :value_options, :map, default: %{}
  attr :contact_options, :map, default: %{}

  def conversation_filter_condition(assigns) do
    ~H"""
    <li id={"condition-row-#{@index}"} class="grid gap-2">
      <.conversation_filter_select
        :if={@index > 0}
        id={"condition-join-#{@index}"}
        field={@previous[:query_operator]}
        index={@index - 1}
        options={[{"and", "AND"}, {"or", "OR"}]}
        event="filter:pick_join"
        join_picker
        class="w-24"
      />
      <div class="grid grid-cols-[minmax(0,1fr)_auto] sm:grid-cols-[1fr_1fr_1fr_auto] gap-2 items-center">
        <.conversation_filter_select
          id={"condition-attribute-#{@index}"}
          field={@row[:attribute_key]}
          index={@index}
          options={@attributes}
          class="col-span-2 sm:col-span-1 min-w-0"
        />
        <.conversation_filter_select
          id={"condition-operator-#{@index}"}
          field={@row[:filter_operator]}
          index={@index}
          options={operators_for(@row[:attribute_key].value, @definition)}
          class="col-span-2 sm:col-span-1 min-w-0"
        />
        <.conversation_filter_select
          :if={
            @row[:filter_operator].value not in ~w(is_present is_not_present) &&
              @row[:attribute_key].value in ~w(assignee_id inbox_id team_id contact_id campaign_id browser_language)
          }
          id={"condition-values-#{@index}"}
          field={@row[:values]}
          index={@index}
          options={
            if(@row[:attribute_key].value == "contact_id",
              do: Map.get(@contact_options, @index, []),
              else: Map.get(@value_options, @row[:attribute_key].value, [])
            )
          }
          event="filter:pick_value"
          search_event={if(@row[:attribute_key].value == "contact_id", do: "filter:search_contact")}
          value_picker
          class="min-w-0"
        />
        <.conversation_filter_multi_select
          :if={
            @row[:filter_operator].value not in ~w(is_present is_not_present) &&
              @row[:attribute_key].value in ~w(status priority labels)
          }
          id={"condition-values-#{@index}"}
          field={@row[:values]}
          index={@index}
          options={multi_options(@row[:attribute_key].value, @labels)}
        />
        <.next_input
          :if={
            @row[:filter_operator].value not in ~w(is_present is_not_present) &&
              @row[:attribute_key].value not in ~w(status priority labels assignee_id inbox_id team_id contact_id campaign_id browser_language) &&
              (is_nil(@definition) || @definition.attribute_display_type not in [:checkbox, :list])
          }
          field={@row[:values]}
          type={value_type(@row[:attribute_key].value, @row[:filter_operator].value, @definition)}
          step={if(@definition && @definition.attribute_display_type == :number, do: "any")}
          min={if(@row[:filter_operator].value == "days_before", do: 1)}
          max={if(@row[:filter_operator].value == "days_before", do: 998)}
          size={:sm}
          placeholder="Enter value"
          class="flex-1"
        />
        <.conversation_filter_select
          :if={
            @row[:filter_operator].value not in ~w(is_present is_not_present) &&
              @definition && @definition.attribute_display_type in [:checkbox, :list]
          }
          id={"condition-values-#{@index}"}
          field={@row[:values]}
          index={@index}
          options={value_options(@definition)}
          event="filter:pick_custom_value"
          value_picker
          class="min-w-0"
        />
        <input
          :if={@row[:filter_operator].value in ~w(is_present is_not_present)}
          type="hidden"
          id={@row[:values].id}
          name={@row[:values].name}
          value={@row[:values].value}
        />
        <input
          :if={@row[:attribute_key].value in ["created_at", "last_activity_at"]}
          type="hidden"
          name={@row[:timezone].name}
          value={@row[:timezone].value || ""}
          data-filter-timezone
        />
        <.next_button
          id={"remove-condition-#{@index}"}
          icon="ph-trash"
          color={:ruby}
          variant={:ghost}
          size={:sm}
          title="Remove filter"
          phx-click="filter:remove"
          phx-value-index={@index}
        />
      </div>
    </li>
    """
  end

  defp operators_for(_key, %{attribute_display_type: type}) do
    valid =
      case type do
        :text -> ~w(equal_to not_equal_to contains does_not_contain)
        :date -> ~w(equal_to not_equal_to is_present is_not_present is_greater_than is_less_than)
        _ -> ~w(equal_to not_equal_to)
      end

    Enum.filter(@operators, fn {operator, _label} -> operator in valid end)
  end

  defp operators_for(key, nil) do
    valid =
      case key do
        key when key in ~w(created_at last_activity_at) ->
          ~w(is_greater_than is_less_than days_before)

        key when key in ~w(display_id referer mail_subject) ->
          ~w(equal_to not_equal_to contains does_not_contain)

        key when key in ~w(status priority contact_id browser_language conversation_language) ->
          ~w(equal_to not_equal_to)

        _ ->
          ~w(equal_to not_equal_to is_present is_not_present)
      end

    Enum.filter(@operators, fn {operator, _label} -> operator in valid end)
  end

  defp value_type(_key, _operator, %{attribute_display_type: :date}), do: "date"
  defp value_type(_key, _operator, %{attribute_display_type: :number}), do: "number"
  defp value_type(_key, "days_before", _definition), do: "number"

  defp value_type(key, _operator, _definition) when key in ~w(created_at last_activity_at),
    do: "date"

  defp value_type(_key, _operator, _definition), do: "text"

  defp value_options(%{attribute_display_type: :checkbox}),
    do: [{"true", "True"}, {"false", "False"}]

  defp value_options(%{attribute_values: values}) when is_list(values),
    do: values |> Enum.filter(&is_binary/1) |> Enum.map(&{&1, &1})

  defp value_options(_definition), do: []

  defp multi_options("status", _labels),
    do: Enum.map(~w(open resolved pending snoozed), &{&1, String.capitalize(&1)})

  defp multi_options("priority", _labels),
    do: Enum.map(~w(low medium high urgent), &{&1, String.capitalize(&1)})

  defp multi_options("labels", labels), do: Enum.map(labels, &{&1.title, &1.title})
end
