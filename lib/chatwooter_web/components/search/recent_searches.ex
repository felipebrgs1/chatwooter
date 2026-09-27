defmodule ChatwooterWeb.Components.Search.RecentSearches do
  @moduledoc """
  Buscas recentes — port de `modules/search/components/RecentSearches.vue`.
  A lista (máx. 3) vem do LiveView; os cliques disparam `select_recent_search`
  e `clear_recent_searches`.
  """
  use ChatwooterWeb, :component

  attr :searches, :list, required: true

  def search_recent_searches(assigns) do
    ~H"""
    <div :if={@searches != []} id="recent-searches" class="px-4 pb-4 w-full pt-2">
      <div class="flex items-center justify-between mb-4">
        <div class="flex items-center gap-2.5">
          <span class="ph-arrow-counter-clockwise text-n-slate-10 size-4" />
          <h3 class="text-base font-medium text-n-slate-10">Recent searches</h3>
        </div>
        <.next_button
          id="recent-searches-clear"
          label="Clear all"
          size={:xs}
          color={:slate}
          variant={:ghost}
          class="!text-n-slate-10 hover:!text-n-slate-12"
          data-keep-focus
          phx-click="clear_recent_searches"
        />
      </div>

      <div class="flex flex-col gap-4 items-start">
        <button
          :for={{search, index} <- Enum.with_index(@searches)}
          id={"recent-search-#{index}"}
          type="button"
          data-keep-focus
          phx-click="select_recent_search"
          phx-value-q={search}
          class="w-full flex items-center gap-2.5 text-left text-base text-n-slate-12 rounded-lg transition-all duration-150 group p-0"
        >
          <span class="ph-magnifying-glass text-n-slate-10 group-hover:text-n-slate-11 transition-colors duration-150 size-4" />
          <span class="flex-1 truncate">{search}</span>
          <span class="text-xs text-n-slate-8 opacity-0 group-hover:opacity-100 transition-opacity duration-150">
            {if index == 0, do: "Most recent"}
          </span>
        </button>
      </div>
    </div>
    """
  end
end
