defmodule ChatwooterWeb.Components.Search.SearchResultSection do
  @moduledoc """
  Seção de resultados — port de `modules/search/components/SearchResultSection.vue`.
  Sem o `woot-loading-state`: a busca roda no próprio evento do LiveView.
  """
  use ChatwooterWeb, :component

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :empty, :boolean, default: false
  attr :query, :string, default: ""
  attr :show_title, :boolean, default: true
  attr :class, :any, default: nil
  slot :inner_block

  def search_result_section(assigns) do
    ~H"""
    <section id={@id} class={["mx-0 mb-3", @class]}>
      <div
        :if={@show_title}
        class="sticky top-0 pt-2 py-3 z-20 bg-gradient-to-b from-n-surface-1 from-80% to-transparent mb-3 -mx-1.5 px-1.5"
      >
        <h3 class="text-sm text-n-slate-11">{@title}</h3>
      </div>
      {render_slot(@inner_block)}
      <div
        :if={@empty}
        class="flex items-start justify-center px-4 py-6 rounded-xl bg-n-slate-2 dark:bg-n-solid-1"
      >
        <span class="ph-info text-n-slate-11 size-4 flex-shrink-0 mt-[3px]" />
        <p class="mx-2 my-0 text-center text-n-slate-11">
          No {String.downcase(@title)} found for query '{@query}'
        </p>
      </div>
    </section>
    """
  end
end
