defmodule ChatwooterWeb.Components.Conversation.FilterSelect do
  @moduledoc """
  Port of components-next/filter/inputs/FilterSelect.vue (and the single-value trigger of
  SingleSelect.vue with `value_picker`): an auto-width button that opens a `DropdownBody`.
  """
  use ChatwooterWeb, :component

  # filter/helper/filterHelper.js → DROPDOWN_SEARCH_THRESHOLD
  @search_threshold 8

  attr :id, :string, required: true
  attr :field, Phoenix.HTML.FormField, required: true
  attr :index, :integer, required: true
  attr :options, :list, required: true
  attr :class, :any, default: nil
  attr :event, :string, default: "filter:pick"
  attr :variant, :atom, default: :faded
  attr :hide_icon, :boolean, default: false
  attr :value_picker, :boolean, default: false
  attr :search_event, :string, default: nil

  def conversation_filter_select(assigns) do
    options =
      Enum.map(assigns.options, fn
        {value, label} -> %{value: value, label: label}
        option when is_map(option) -> option
      end)

    selected =
      Enum.find(
        options,
        &(!Map.get(&1, :disabled) && to_string(&1.value) == to_string(assigns.field.value))
      )

    assigns =
      assign(assigns,
        options: options,
        selected: selected,
        # Async contact search always needs its input, even before the first results arrive.
        show_search: assigns.search_event != nil || length(options) > @search_threshold
      )

    ~H"""
    <div
      id={"#{@id}-picker"}
      phx-hook=".FilterPicker"
      class={["relative min-w-0", @class]}
      phx-click-away={JS.set_attribute({"hidden", ""}, to: "##{@id}-dropdown")}
    >
      <input type="hidden" id={@field.id} name={@field.name} value={@field.value} />
      <div id={@id} class="contents">
        <.next_button
          :if={@selected || !@value_picker}
          color={:slate}
          variant={@variant}
          size={:sm}
          icon={
            cond do
              @hide_icon -> nil
              @selected && Map.get(@selected, :icon) -> @selected.icon
              @value_picker -> nil
              true -> "ph-caret-down"
            end
          }
          trailing_icon={!@value_picker && !(@selected && Map.get(@selected, :icon))}
          label={@selected && @selected.label}
          class="max-w-full"
          phx-click={toggle(@id)}
        />
        <.next_button
          :if={!@selected && @value_picker}
          color={:slate}
          variant={:faded}
          size={:sm}
          class="max-w-full"
          phx-click={toggle(@id)}
        >
          <span class="ph-plus size-4 shrink-0 text-n-slate-11" aria-hidden="true" />
          <span class="text-n-slate-11 min-w-0 truncate">Select an option...</span>
        </.next_button>
        <.searchable_list
          id={"#{@id}-dropdown"}
          hidden
          class="absolute top-0 z-50 min-w-56 text-sm bg-n-alpha-3 backdrop-blur-[100px] border border-n-strong rounded-xl shadow-sm py-2 px-2 grid gap-2"
        >
          <div :if={@show_search} class="relative">
            <span class="ph-magnifying-glass absolute size-4 left-2 top-2" aria-hidden="true" />
            <input
              type="search"
              data-search-input
              form="searchable-list-detached"
              phx-keyup={@search_event}
              phx-debounce={if(@search_event, do: "300")}
              phx-value-index={@index}
              placeholder="Search..."
              class="w-full p-1.5 pl-8 rounded-lg text-n-slate-11 bg-n-alpha-1 border-none focus:outline-none"
            />
          </div>
          <ul role="listbox" class="-mx-2 px-2 grid gap-2 list-none max-h-72 overflow-y-auto">
            <%= for option <- @options do %>
              <li
                :if={Map.get(option, :disabled, false)}
                id={"#{@id}-group-#{option.value}"}
                data-search-header
                class="px-2 py-1.5 text-xs font-medium text-n-slate-10 select-none"
              >
                {option.label}
              </li>
              <li
                :if={!Map.get(option, :disabled, false)}
                id={"#{@id}-option-#{option.value}"}
                data-search-item
                data-search-text={option.label}
                data-option-value={option.value}
                role="option"
                aria-selected={to_string(@selected == option)}
                phx-click={
                  JS.push(@event, value: %{index: @index, field: @field.field, value: option.value})
                  |> JS.set_attribute({"hidden", ""}, to: "##{@id}-dropdown")
                }
                class="flex items-center gap-3 p-2 text-sm text-n-slate-12 rounded-lg cursor-pointer hover:bg-n-alpha-2"
              >
                <span
                  :if={Map.get(option, :icon)}
                  class={[option.icon, "size-4 shrink-0 text-n-slate-11"]}
                  aria-hidden="true"
                />
                {option.label}
              </li>
            <% end %>
            <li data-search-empty hidden class="p-2 text-sm text-n-slate-11">
              No results found.
            </li>
          </ul>
        </.searchable_list>
      </div>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".FilterPicker">
        export default {
          mounted() {
            // Keep the submitted value current while the server acknowledges the selection.
            this.el.addEventListener('click', event => {
              const option = event.target.closest('[data-option-value]')
              if (option) this.el.querySelector('input[type=hidden]').value = option.dataset.optionValue
            }, true)
            this.el.addEventListener('click', event => {
              if (event.target.closest('button') !== this.el.querySelector('button')) return
              const input = this.el.querySelector('input[type=search]')
              if (input && input.value) {
                input.value = ''
                input.dispatchEvent(new Event('input', {bubbles: true}))
              }
            })
            this.el.addEventListener('keydown', event => {
              const dropdown = this.el.querySelector('[id$="-dropdown"]')
              if (!dropdown || dropdown.hidden) return
              const options = [...dropdown.querySelectorAll('[role=option]')].filter(option => !option.hidden)
              const index = options.indexOf(document.activeElement)
              if (event.key === 'Escape') {
                event.preventDefault()
                this.js().setAttribute(dropdown, 'hidden', '')
                this.el.querySelector('button').focus()
              } else if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
                event.preventDefault()
                if (!options.length) return
                const next = index < 0 ? (event.key === 'ArrowDown' ? 0 : options.length - 1) : (index + (event.key === 'ArrowDown' ? 1 : -1) + options.length) % options.length
                options[next].tabIndex = -1
                options[next].focus()
              } else if (event.key === 'Enter' && index >= 0) {
                event.preventDefault()
                options[index].click()
                this.el.querySelector('button').focus()
              }
            })
          }
        }
      </script>
    </div>
    """
  end

  defp toggle(id) do
    JS.toggle_attribute({"hidden", ""}, to: "##{id}-dropdown")
    |> JS.focus(to: "##{id}-dropdown input")
  end
end
