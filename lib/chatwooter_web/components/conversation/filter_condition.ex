defmodule ChatwooterWeb.Components.Conversation.FilterCondition do
  @moduledoc "Port of components-next/filter/ConditionRow.vue; native pickers remain temporary."
  use ChatwooterWeb, :component

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

  def conversation_filter_condition(assigns) do
    ~H"""
    <li id={"condition-row-#{@index}"} class="grid gap-2">
      <select
        :if={@index > 0}
        id={"condition-join-#{@index}"}
        name={@previous[:query_operator].name}
        class="rounded-lg border border-n-weak bg-n-solid-1 text-sm h-8"
      >
        <option
          :for={join <- ["and", "or"]}
          value={join}
          selected={@previous[:query_operator].value == join}
        >
          {String.upcase(join)}
        </option>
      </select>
      <div class="grid grid-cols-[minmax(0,1fr)_auto] sm:grid-cols-[1fr_1fr_1fr_auto] gap-2 items-center">
        <select
          id={"condition-attribute-#{@index}"}
          name={@row[:attribute_key].name}
          class="col-span-2 sm:col-span-1 min-w-0 rounded-lg border border-n-weak bg-n-solid-1 text-sm h-8"
          aria-label="Attribute"
        >
          <option
            :for={{key, label} <- @attributes}
            value={key}
            selected={@row[:attribute_key].value == key}
          >
            {label}
          </option>
        </select>
        <select
          id={"condition-operator-#{@index}"}
          name={@row[:filter_operator].name}
          class="col-span-2 sm:col-span-1 min-w-0 rounded-lg border border-n-weak bg-n-solid-1 text-sm h-8"
          aria-label="Operator"
        >
          <option
            :for={{key, label} <- operators_for(@row[:attribute_key].value)}
            value={key}
            selected={@row[:filter_operator].value == key}
          >
            {label}
          </option>
        </select>
        <.next_input
          field={@row[:values]}
          type={value_type(@row[:attribute_key].value, @row[:filter_operator].value)}
          min={if(@row[:filter_operator].value == "days_before", do: 1)}
          max={if(@row[:filter_operator].value == "days_before", do: 998)}
          size={:sm}
          placeholder="Enter value"
          class="flex-1"
          disabled={@row[:filter_operator].value in ["is_present", "is_not_present"]}
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

  defp operators_for(key) do
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

  defp value_type(_key, "days_before"), do: "number"
  defp value_type(key, _operator) when key in ~w(created_at last_activity_at), do: "date"
  defp value_type(_key, _operator), do: "text"
end
