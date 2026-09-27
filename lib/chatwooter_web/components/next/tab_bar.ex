defmodule ChatwooterWeb.Components.Next.TabBar do
  @moduledoc "Port de `components-next/tabbar/TabBar.vue`."
  use ChatwooterWeb, :base_component

  @doc """
  `components-next/tabbar/TabBar.vue`. O indicador deslizante vira o fundo da aba ativa.
  Cada aba é `%{value:, label:, count:}`; o clique faz `JS.push(event, value: %{tab: value})`.
  """
  attr :id, :string, required: true
  attr :tabs, :list, required: true
  attr :active, :string, required: true
  attr :event, :string, required: true
  attr :class, :any, default: nil

  def tab_bar(assigns) do
    ~H"""
    <div
      id={@id}
      role="tablist"
      class={[
        "relative flex items-center h-8 rounded-lg bg-n-alpha-1 dark:bg-n-solid-1 w-fit transition-all duration-200 ease-out has-[button:active]:scale-[1.01]",
        @class
      ]}
    >
      <%= for {tab, index} <- Enum.with_index(@tabs) do %>
        <button
          id={"#{@id}-#{tab.value}"}
          type="button"
          role="tab"
          aria-selected={to_string(tab.value == @active)}
          phx-click={JS.push(@event, value: %{tab: tab.value})}
          class={[
            "relative z-10 px-4 truncate py-1.5 h-8 text-sm border-0 outline-1 rounded-lg transition-all duration-200 ease-out hover:text-n-brand active:scale-[1.02]",
            if(tab.value == @active,
              do: "text-n-blue-11 scale-100 bg-n-solid-active shadow-sm outline outline-n-container",
              else: "text-n-slate-10 scale-[0.98] outline-transparent"
            )
          ]}
        >
          {tab.label}{if(tab[:count], do: " (#{tab.count})")}
        </button>
        <div
          :if={index < length(@tabs) - 1}
          class={[
            "w-px h-3.5 rounded my-auto transition-colors duration-300 ease-in-out shrink-0",
            if(tab.value != @active and Enum.at(@tabs, index + 1).value != @active,
              do: "bg-n-strong",
              else: "bg-transparent"
            )
          ]}
        />
      <% end %>
    </div>
    """
  end
end
