defmodule ChatwooterWeb.Components.Next.Breadcrumb do
  @moduledoc "Port de `components-next/breadcrumb/Breadcrumb.vue`."
  use ChatwooterWeb, :base_component

  @doc "`components-next/breadcrumb/Breadcrumb.vue`. Itens: `%{label:, navigate:}`; o último é texto."
  attr :id, :string, default: nil
  attr :items, :list, required: true

  def breadcrumb(assigns) do
    ~H"""
    <nav id={@id} aria-label="Breadcrumb" class="flex items-center h-8 min-w-0">
      <ol class="flex items-center mb-0 min-w-0">
        <%= for {item, index} <- Enum.with_index(@items) do %>
          <li class={["flex items-center", index == length(@items) - 1 && "min-w-0 flex-1"]}>
            <span :if={index > 0} class="ph-caret-right flex-shrink-0 mx-2 size-4 text-n-slate-11" />
            <.link
              :if={index != length(@items) - 1}
              navigate={item.navigate}
              class="inline-flex items-center justify-center min-w-0 gap-2 p-0 text-sm font-medium transition-all duration-200 ease-in-out border-0 rounded-lg text-n-slate-11 hover:text-n-slate-12 outline-transparent max-w-56"
            >
              <span class="min-w-0 truncate">{item.label}</span>
            </.link>
            <span
              :if={index == length(@items) - 1}
              class="inline-flex items-center gap-1 text-sm truncate min-w-0"
            >
              <span class="truncate text-n-slate-12">{item.label}</span>
            </span>
          </li>
        <% end %>
      </ol>
    </nav>
    """
  end
end
