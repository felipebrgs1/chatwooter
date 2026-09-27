defmodule ChatwooterWeb.Components.Next.Switch do
  @moduledoc "Port de `components-next/switch/Switch.vue`."
  use ChatwooterWeb, :base_component

  @doc "`components-next/switch/Switch.vue`."
  attr :id, :string, required: true
  attr :checked, :boolean, default: false
  attr :rest, :global, include: ~w(phx-click phx-value-key disabled)

  def next_switch(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      role="switch"
      aria-checked={to_string(@checked)}
      class={[
        "group relative h-4 rounded-full w-7 flex-shrink-0 select-none focus:outline-none focus:ring-1 focus:ring-n-brand focus:ring-offset-n-slate-2 focus:ring-offset-2 transition-colors duration-200 ease-in-out",
        if(@checked, do: "bg-n-brand", else: "bg-n-slate-6")
      ]}
      {@rest}
    >
      <span class="sr-only">Toggle</span>
      <span class={[
        "absolute top-1/2 left-0.5 -translate-y-1/2 transition-transform duration-[350ms] ease-[cubic-bezier(0.34,1.56,0.64,1)]",
        if(@checked, do: "translate-x-3 group-active:translate-x-[6px]", else: "translate-x-0")
      ]}>
        <span class="block h-3 w-3 rounded-full bg-n-background shadow-md transition-[width] duration-[180ms] ease-in-out group-active:w-[18px]" />
      </span>
    </button>
    """
  end
end
