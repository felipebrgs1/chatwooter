defmodule ChatwooterWeb.Components.Conversation.FilterSelect do
  @moduledoc "Port of components-next/filter/inputs/FilterSelect.vue using the shared searchable ComboBox."
  use ChatwooterWeb, :component

  attr :id, :string, required: true
  attr :field, Phoenix.HTML.FormField, required: true
  attr :index, :integer, required: true
  attr :options, :list, required: true
  attr :class, :any, default: nil
  attr :event, :string, default: "filter:pick"
  attr :value_picker, :boolean, default: false
  attr :join_picker, :boolean, default: false
  attr :search_event, :string, default: nil

  def conversation_filter_select(assigns) do
    assigns =
      assign(
        assigns,
        :options,
        Enum.map(assigns.options, fn
          {value, label} -> %{value: value, label: label}
          option when is_map(option) -> option
        end)
      )

    ~H"""
    <div id={"#{@id}-picker"} phx-hook=".FilterPicker" class={@class}>
      <input type="hidden" id={@field.id} name={@field.name} value={@field.value} />
      <.combobox
        id={@id}
        options={@options}
        value={@field.value}
        event={@event}
        search_event={@search_event}
        search_index={@index}
        list_class={@value_picker && "max-h-28! sm:max-h-56!"}
        dropdown_class={
          cond do
            @value_picker ->
              "bottom-full mb-1 mt-0 sm:bottom-auto sm:right-full sm:top-0 sm:me-2 sm:mb-0"

            @join_picker ->
              "min-w-48!"

            true ->
              nil
          end
        }
        event_values={%{index: @index, field: @field.field}}
      />
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
end
