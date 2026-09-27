defmodule ChatwooterWeb.Components.Conversation.FilterMultiSelect do
  @moduledoc "Port of components-next/filter/inputs/MultiSelect.vue for fixed conversation values."
  use ChatwooterWeb, :component
  import ChatwooterWeb.Components.Next.SearchableList

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
        type="button"
        class="flex h-8 max-w-full items-center gap-1 rounded-lg bg-n-alpha-2 px-2 text-sm text-n-slate-12"
        phx-click={
          JS.toggle_attribute({"hidden", ""}, to: "##{@id}-dropdown")
          |> JS.focus(to: "##{@id}-dropdown input")
        }
      >
        <%= if @selected == [] do %>
          <span class="ph-plus size-4" aria-hidden="true" /> Select an option...
        <% else %>
          <span
            :for={{value, label} <- @options}
            :if={value in @selected}
            id={"#{@id}-chip-#{value}"}
            class="max-w-24 truncate border-r border-n-weak px-1"
          >{label}</span>
          <span class="ph-plus size-4" aria-hidden="true" />
        <% end %>
      </button>
      <.searchable_list
        id={"#{@id}-dropdown"}
        hidden
        class="absolute bottom-full z-50 mb-1 min-w-48 rounded-lg border border-n-strong bg-n-solid-1 shadow-lg sm:bottom-auto sm:right-full sm:top-0 sm:me-2 sm:mb-0"
      >
        <div class="relative border-b border-n-strong">
          <span class="ph-magnifying-glass absolute top-2.5 start-3 size-4" />
          <input
            type="search"
            data-search-input
            form="searchable-list-detached"
            placeholder="Search..."
            class="w-full bg-n-solid-1 py-2 ps-10 pe-2 text-sm"
          />
        </div>
        <ul role="listbox" aria-multiselectable="true" class="max-h-72 overflow-auto py-1">
          <li
            :for={{value, label} <- @options}
            id={"#{@id}-option-#{value}"}
            data-search-item
            data-search-text={label}
            role="option"
            aria-selected={value in @selected}
            class="flex cursor-pointer items-center justify-between gap-2 px-3 py-2 text-sm hover:bg-n-alpha-2"
            phx-click={JS.push("filter:toggle_value", value: %{index: @index, value: value})}
          >
            {label}
            <span :if={value in @selected} class="ph-check size-4 text-n-blue-11" />
          </li>
          <li data-search-empty hidden class="px-3 py-2 text-sm text-n-slate-11">
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
end
