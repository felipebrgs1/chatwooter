defmodule ChatwooterWeb.Components.Next.DropdownMenu do
  @moduledoc "Port de `components-next/dropdown-menu/DropdownMenu.vue` (com `show-search`)."
  use ChatwooterWeb, :base_component

  import ChatwooterWeb.Components.Next.SearchableList

  @doc """
  `components-next/dropdown-menu/DropdownMenu.vue` com `show-search`. Fica escondido;
  abra com `JS.toggle_attribute({"hidden", ""}, to: "#<id>")`. O slot `:item` recebe cada item.
  """
  attr :id, :string, required: true
  attr :items, :list, required: true
  attr :event, :string, required: true
  attr :selected, :any, default: nil
  attr :search_placeholder, :string, default: "Search..."
  attr :class, :any, default: nil
  slot :item

  def dropdown_menu(assigns) do
    ~H"""
    <.searchable_list
      id={@id}
      hidden
      class={[
        "bg-n-alpha-3 backdrop-blur-[100px] border-0 outline outline-1 outline-n-container absolute rounded-xl z-50 flex flex-col min-w-[136px] shadow-lg pt-2 overflow-hidden",
        @class
      ]}
    >
      <div class="relative shrink-0 px-2 mb-2">
        <span class="absolute ph-magnifying-glass size-3.5 top-2.5 left-5" />
        <input
          type="search"
          data-search-input
          form="searchable-list-detached"
          placeholder={@search_placeholder}
          class="w-full h-8 py-2 pl-10 pr-2 text-sm focus:outline-none border-none rounded-lg bg-n-alpha-black2 dark:bg-n-solid-1 text-n-slate-12"
        />
      </div>
      <div class="flex flex-col gap-2 overflow-y-auto min-h-0 px-2 pb-2">
        <button
          :for={item <- @items}
          id={"#{@id}-option-#{item.value}"}
          type="button"
          data-search-item
          data-search-text={item.label}
          phx-click={
            JS.push(@event, value: %{value: item.value})
            |> JS.set_attribute({"hidden", ""}, to: "##{@id}")
          }
          class={[
            "inline-flex items-center justify-start w-full h-8 min-w-0 gap-2 px-2 py-1.5 transition-all duration-200 ease-in-out border-0 rounded-lg hover:bg-n-alpha-1 dark:hover:bg-n-alpha-2 text-n-slate-12",
            to_string(item.value) == to_string(@selected) && "bg-n-alpha-1 dark:bg-n-solid-active"
          ]}
        >
          {render_slot(@item, item)}
          <span class="min-w-0 text-sm font-420 truncate">{item.label}</span>
        </button>
        <p data-search-empty hidden class="text-sm text-n-slate-11 px-2 py-1.5 mb-0">
          No results found.
        </p>
      </div>
    </.searchable_list>
    """
  end
end
