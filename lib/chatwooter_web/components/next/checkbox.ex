defmodule ChatwooterWeb.Components.Next.Checkbox do
  @moduledoc """
  Port of `components-next/checkbox/Checkbox.vue`, drawn from server state: it lives inside
  links (conversation card) where a real `<input>` would fight the navigation, so the
  parent handles the click and re-renders `checked`.
  """
  use ChatwooterWeb, :base_component

  attr :checked, :boolean, default: false
  attr :indeterminate, :boolean, default: false
  attr :class, :any, default: nil

  def next_checkbox(assigns) do
    ~H"""
    <span
      role="checkbox"
      aria-checked={if(@indeterminate, do: "mixed", else: to_string(@checked))}
      class={["relative block w-4 h-4 flex-shrink-0", @class]}
    >
      <span class={[
        "absolute inset-0 h-4 w-4 rounded border transition-all duration-200 cursor-pointer",
        if(@checked || @indeterminate,
          do: "border-n-brand bg-n-brand",
          else: "border-n-slate-6 hover:bg-n-blue-border"
        )
      ]} />
      <svg
        :if={@checked && !@indeterminate}
        viewBox="0 0 14 14"
        fill="none"
        class="pointer-events-none absolute w-3.5 h-3.5 stroke-white left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
      >
        <path d="M3 8L6 11L11 3.5" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
      </svg>
      <svg
        :if={@indeterminate}
        viewBox="0 0 14 14"
        fill="none"
        class="pointer-events-none absolute w-3.5 h-3.5 stroke-white left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
      >
        <path d="M3 7L11 7" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
      </svg>
    </span>
    """
  end
end
