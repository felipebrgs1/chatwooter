defmodule ChatwooterWeb.Components.Conversation.FilterMultiSelect do
  @moduledoc "Port of components-next/filter/inputs/MultiSelect.vue for fixed conversation values."
  use ChatwooterWeb, :component

  attr :id, :string, required: true
  attr :field, Phoenix.HTML.FormField, required: true
  attr :index, :integer, required: true
  attr :options, :list, required: true

  def conversation_filter_multi_select(assigns) do
    selected =
      case Jason.decode(assigns.field.value || "") do
        {:ok, values} when is_list(values) -> values
        _ -> String.split(assigns.field.value || "", ",", trim: true)
      end

    assigns = assign(assigns, :selected, selected)

    ~H"""
    <div
      id={@id}
      class="relative min-w-0"
      phx-hook=".FilterMultiSelect"
      phx-click-away={JS.set_attribute({"hidden", ""}, to: "##{@id}-dropdown")}
    >
      <input type="hidden" id={@field.id} name={@field.name} value={@field.value} />
      <button
        :if={@selected != []}
        type="button"
        class="bg-n-alpha-2 py-2 rounded-lg h-8 flex items-center px-0 max-w-full"
        phx-click={toggle(@id)}
      >
        <span
          :for={{value, label} <- @options}
          :if={value in @selected}
          id={"#{@id}-chip-#{value}"}
          class="px-3 border-e border-n-weak text-n-slate-12 text-sm flex gap-2 items-center max-w-[100px] min-w-0"
        >
          <span class="truncate">{label}</span>
        </span>
        <span class="flex items-center border-none px-3 gap-2 flex-shrink-0">
          <span class="ph-plus size-4" aria-hidden="true" />
        </span>
      </button>
      <.next_button
        :if={@selected == []}
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
        class="absolute top-0 z-50 min-w-48 text-sm bg-n-alpha-3 backdrop-blur-[100px] border border-n-strong rounded-xl shadow-sm py-2 px-2 grid gap-2"
      >
        <div :if={length(@options) > 8} class="relative">
          <span class="ph-magnifying-glass absolute size-4 start-2 top-2" aria-hidden="true" />
          <input
            type="search"
            data-search-input
            form="searchable-list-detached"
            placeholder="Search..."
            class="w-full p-1.5 ps-8 rounded-lg text-n-slate-11 bg-n-alpha-1 border-none focus:outline-none"
          />
        </div>
        <ul
          role="listbox"
          aria-multiselectable="true"
          class="-mx-2 px-2 grid gap-2 list-none max-h-72 overflow-y-auto"
        >
          <li
            :for={{value, label} <- @options}
            id={"#{@id}-option-#{value}"}
            data-search-item
            data-search-text={label}
            role="option"
            aria-selected={value in @selected}
            class="flex cursor-pointer items-center justify-between gap-3 p-2 text-sm text-n-slate-12 rounded-lg hover:bg-n-alpha-2"
            phx-click={JS.push("filter:toggle_value", value: %{index: @index, value: value})}
          >
            {label}
            <span :if={value in @selected} class="ph-check size-4 text-n-blue-11" />
          </li>
          <li data-search-empty hidden class="p-2 text-sm text-n-slate-11">
            No results found.
          </li>
        </ul>
      </.searchable_list>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".FilterMultiSelect">
        export default {
          mounted() {
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
                const step = event.key === 'ArrowDown' ? 1 : -1
                const next = index < 0 ? (step > 0 ? 0 : options.length - 1) : (index + step + options.length) % options.length
                options[next].tabIndex = -1
                options[next].focus()
              } else if (event.key === 'Enter' && index >= 0) {
                // Multiselect keeps the menu open, like MultiSelect.vue.
                event.preventDefault()
                options[index].click()
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
