defmodule ChatwooterWeb.Components.Next.SearchableList do
  @moduledoc "Lista com filtro local (hook `.SearchableList`)."
  use ChatwooterWeb, :base_component

  @doc """
  Contêiner com busca local: filtra filhos `[data-search-item]` (texto em
  `data-search-text`) pelo `[data-search-input]`; `[data-search-empty]` aparece sem resultados.
  Base do `combobox/1` e do `dropdown_menu/1`.
  """
  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def searchable_list(assigns) do
    ~H"""
    <div id={@id} phx-hook=".SearchableList" class={@class} {@rest}>
      {render_slot(@inner_block)}
      <script :type={Phoenix.LiveView.ColocatedHook} name=".SearchableList">
        // Filtro local das listas com busca (ComboBox / DropdownMenu do Chatwoot)
        // A busca usa form="searchable-list-detached" para não disparar o phx-change
        // do formulário em volta; this.js() mantém o filtro depois dos patches.
        export default {
          setHidden(el, hidden) {
            if (hidden) this.js().setAttribute(el, "hidden", "")
            else this.js().removeAttribute(el, "hidden")
          },
          mounted() {
            this.el.addEventListener("input", e => {
              if (!e.target.matches("[data-search-input]")) return
              const query = e.target.value.trim().toLowerCase()
              this.el.querySelectorAll("[data-search-header]").forEach(header => this.setHidden(header, query.length > 0))
              let visible = 0
              this.el.querySelectorAll("[data-search-item]").forEach(item => {
                const match = item.dataset.searchText.toLowerCase().includes(query)
                this.setHidden(item, !match)
                if (match) visible++
              })
              const empty = this.el.querySelector("[data-search-empty]")
              if (empty) this.setHidden(empty, visible > 0)
            })
          }
        }
      </script>
    </div>
    """
  end
end
