defmodule ChatwooterWeb.Components.Next.Combobox do
  @moduledoc "Port de `components-next/combobox/ComboBox.vue` + `ComboBoxDropdown.vue`."
  use ChatwooterWeb, :base_component

  import ChatwooterWeb.Components.Next.Button
  import ChatwooterWeb.Components.Next.SearchableList

  @doc """
  `components-next/combobox/ComboBox.vue`: botão + lista com busca. Cada opção é
  `%{value: ..., label: ...}`; o clique faz `JS.push(event, value: %{value: ...})`.
  Opções ganham o id `"<id>-option-<value>"`.
  """
  attr :id, :string, required: true
  attr :options, :list, required: true
  attr :value, :any, default: nil
  attr :event, :string, required: true
  attr :placeholder, :string, default: "Select an option..."
  attr :search_placeholder, :string, default: "Search..."
  attr :empty_state, :string, default: "No results found."
  attr :class, :any, default: nil

  def combobox(assigns) do
    selected = Enum.find(assigns.options, &(to_string(&1.value) == to_string(assigns.value)))
    assigns = assign(assigns, :selected, selected)

    ~H"""
    <div
      id={@id}
      class={["relative w-full min-w-0 group/combobox", @class]}
      phx-click-away={JS.set_attribute({"hidden", ""}, to: "##{@id}-dropdown")}
    >
      <.next_button
        color={:slate}
        variant={:outline}
        icon="ph-caret-down"
        trailing_icon
        no_animation
        size={:md}
        label={if(@selected, do: @selected.label, else: @placeholder)}
        class="justify-between! w-full px-3! py-2.5! h-8! bg-n-alpha-black2! font-normal outline-n-weak! group-hover/combobox:outline-n-slate-6! focus:outline-n-brand! text-n-slate-12"
        phx-click={
          JS.toggle_attribute({"hidden", ""}, to: "##{@id}-dropdown")
          |> JS.focus(to: "##{@id}-dropdown input")
        }
      />
      <.searchable_list
        id={"#{@id}-dropdown"}
        hidden
        class="absolute z-50 w-full mt-1 transition-opacity duration-200 border rounded-md shadow-lg bg-n-solid-1 border-n-strong"
      >
        <div class="relative border-b border-n-strong">
          <span class="ph-magnifying-glass absolute top-2.5 size-4 start-3" />
          <input
            type="search"
            data-search-input
            form="searchable-list-detached"
            placeholder={@search_placeholder}
            class="w-full py-2 ps-10! pe-2! text-sm focus:outline-none border-none rounded-t-md bg-n-solid-1 text-n-slate-12"
          />
        </div>
        <ul class="py-1 mb-0 overflow-auto max-h-56" role="listbox">
          <li
            :for={option <- @options}
            id={"#{@id}-option-#{option.value}"}
            data-search-item
            data-search-text={option.label}
            role="option"
            aria-selected={to_string(@selected == option)}
            phx-click={
              JS.push(@event, value: %{value: option.value})
              |> JS.set_attribute({"hidden", ""}, to: "##{@id}-dropdown")
            }
            class={[
              "flex items-center justify-between w-full gap-2 px-3 py-2 text-sm transition-colors duration-150 cursor-pointer hover:bg-n-alpha-2",
              @selected == option && "bg-n-alpha-2"
            ]}
          >
            <span class={["text-n-slate-12", @selected == option && "font-medium"]}>
              {option.label}
            </span>
            <span :if={@selected == option} class="flex-shrink-0 ph-check size-4 text-n-slate-11" />
          </li>
          <li data-search-empty hidden class="px-3 py-2 text-sm text-n-slate-11">{@empty_state}</li>
        </ul>
      </.searchable_list>
    </div>
    """
  end
end
