defmodule ChatwooterWeb.Components.Search.SearchInput do
  @moduledoc """
  Campo da busca global — port de `modules/search/components/SearchInput.vue`
  (+ `SearchHeader.vue`, que só o embrulha).

  O debounce de 500 ms vira `phx-debounce`. Foco inicial, atalho `/` para focar,
  `Esc` para sair e o `@mousedown.prevent` das buscas recentes ficam no hook
  `.SearchInput`. As buscas recentes aparecem com o input focado e vazio, como
  no `showRecentSearches` — aqui por CSS (`:focus:placeholder-shown`), sem ida
  ao servidor.

  Os filtros (`SearchFilters.vue`) não entram: no Chatwoot só aparecem em
  instalações Enterprise/Cloud com a feature `advanced_search`.
  """
  use ChatwooterWeb, :component

  import ChatwooterWeb.Components.Search.RecentSearches

  attr :query, :string, required: true
  attr :recent_searches, :list, required: true

  def search_input(assigns) do
    ~H"""
    <div
      id="search-input-box"
      phx-hook=".SearchInput"
      class="group/search rounded-xl transition-[border-bottom] duration-[0.2s] ease-[ease-in-out] relative flex items-start flex-col border border-solid bg-n-solid-1 divide-y divide-n-strong border-n-strong has-[input:focus]:border-n-brand"
    >
      <.form
        for={%{}}
        as={:search}
        id="search-form"
        phx-change="search"
        phx-submit="search"
        class="flex items-center w-full h-[3.25rem] px-4 gap-2"
      >
        <div class="flex items-center">
          <span
            class="ph-magnifying-glass size-4 text-n-slate-10 group-has-[input:focus]/search:text-n-blue-11"
            aria-hidden="true"
          />
        </div>
        <input
          id="search-input"
          type="search"
          name="q"
          value={@query}
          phx-debounce="500"
          autocomplete="off"
          placeholder="Type 3 or more characters to search"
          class="reset-base outline-none w-full m-0 bg-transparent border-transparent shadow-none text-n-slate-12 dark:text-n-slate-12 active:border-transparent active:shadow-none hover:border-transparent hover:shadow-none focus:border-transparent focus:shadow-none focus:ring-0 placeholder:text-n-slate-10 text-base"
        />
        <span class="text-sm text-n-slate-10 flex-shrink-0">/to focus</span>
      </.form>

      <div class="transition-all duration-200 ease-out grid overflow-hidden w-full !border-t-0 grid-rows-[0fr] opacity-0 group-has-[input:focus:placeholder-shown]/search:grid-rows-[1fr] group-has-[input:focus:placeholder-shown]/search:opacity-100">
        <div class="overflow-hidden w-full">
          <.search_recent_searches searches={@recent_searches} />
        </div>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".SearchInput">
        export default {
          mounted() {
            this.input = this.el.querySelector('input[type=search]')
            this.input.focus()

            this.onKeydown = e => {
              if (e.key === '/' && document.activeElement.tagName !== 'INPUT') {
                e.preventDefault()
                this.input.focus()
              } else if (e.key === 'Escape' && document.activeElement.tagName === 'INPUT') {
                e.preventDefault()
                this.input.blur()
              }
            }
            document.addEventListener('keydown', this.onKeydown)

            // @mousedown.prevent: o clique na busca recente não tira o foco do input
            this.el.addEventListener('mousedown', e => {
              if (e.target.closest('[data-keep-focus]')) e.preventDefault()
            })

            // o LiveView não reescreve o value de um input focado
            this.handleEvent('search:set-query', ({ q }) => {
              this.input.value = q
              this.input.focus()
            })
          },
          destroyed() {
            document.removeEventListener('keydown', this.onKeydown)
          }
        }
      </script>
    </div>
    """
  end
end
