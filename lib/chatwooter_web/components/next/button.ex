defmodule ChatwooterWeb.Components.Next.Button do
  @moduledoc "Port de `components-next/button/Button.vue`."
  use ChatwooterWeb, :base_component

  # Button.vue → STYLE_CONFIG.colors
  @colors %{
    blue: %{
      solid:
        "bg-n-brand text-white hover:enabled:brightness-110 focus-visible:brightness-110 outline-transparent",
      faded:
        "bg-n-brand/10 text-n-blue-11 hover:enabled:bg-n-brand/20 focus-visible:bg-n-brand/20 outline-transparent",
      outline: "text-n-blue-11 outline-n-brand",
      ghost:
        "text-n-blue-11 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent",
      link: "text-n-blue-11 hover:enabled:underline focus-visible:underline outline-transparent"
    },
    ruby: %{
      solid:
        "bg-n-ruby-9 text-white hover:enabled:bg-n-ruby-10 focus-visible:bg-n-ruby-10 outline-transparent",
      faded:
        "bg-n-ruby-9/10 text-n-ruby-11 hover:enabled:bg-n-ruby-9/20 focus-visible:bg-n-ruby-9/20 outline-transparent",
      outline:
        "text-n-ruby-11 hover:enabled:bg-n-ruby-9/10 focus-visible:bg-n-ruby-9/10 outline-n-ruby-8",
      ghost:
        "text-n-ruby-11 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent",
      link:
        "text-n-ruby-9 dark:text-n-ruby-11 hover:enabled:underline focus-visible:underline outline-transparent"
    },
    amber: %{
      solid:
        "bg-n-amber-9 text-n-amber-12 dark:text-n-amber-3 hover:enabled:bg-n-amber-10 focus-visible:bg-n-amber-10 outline-transparent",
      faded:
        "bg-n-amber-9/10 text-n-slate-12 hover:enabled:bg-n-amber-9/20 focus-visible:bg-n-amber-9/20 outline-transparent",
      outline:
        "text-n-amber-11 hover:enabled:bg-n-amber-9/10 focus-visible:bg-n-amber-9/10 outline-n-amber-9",
      ghost:
        "text-n-amber-9 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent",
      link: "text-n-amber-9 hover:enabled:underline focus-visible:underline outline-transparent"
    },
    slate: %{
      solid:
        "bg-n-button-color dark:hover:enabled:bg-n-solid-2 dark:focus-visible:bg-n-solid-2 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 text-n-slate-12 outline-n-container",
      faded:
        "bg-n-slate-9/10 text-n-slate-12 hover:enabled:bg-n-slate-9/20 focus-visible:bg-n-slate-9/20 outline-transparent",
      outline:
        "text-n-slate-11 outline-n-strong hover:enabled:bg-n-slate-9/10 focus-visible:bg-n-slate-9/10",
      ghost:
        "text-n-slate-12 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent",
      link:
        "text-n-slate-11 hover:enabled:text-n-slate-12 focus-visible:text-n-slate-12 hover:enabled:underline focus-visible:underline outline-transparent"
    },
    teal: %{
      solid:
        "bg-n-teal-9 text-white hover:enabled:bg-n-teal-10 focus-visible:bg-n-teal-10 outline-transparent",
      faded:
        "bg-n-teal-9/10 text-n-teal-11 hover:enabled:bg-n-teal-9/20 focus-visible:bg-n-teal-9/20 outline-transparent",
      outline:
        "text-n-teal-11 hover:enabled:bg-n-teal-9/10 focus-visible:bg-n-teal-9/10 outline-n-teal-9",
      ghost:
        "text-n-teal-9 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent",
      link: "text-n-teal-9 hover:enabled:underline focus-visible:underline outline-transparent"
    }
  }

  @sizes %{
    regular: %{xs: "h-6 px-2", sm: "h-8 px-3", md: "h-10 px-4", lg: "h-12 px-5"},
    icon_only: %{xs: "h-6 w-6 p-0", sm: "h-8 w-8 p-0", md: "h-10 w-10 p-0", lg: "h-12 w-12 p-0"}
  }

  @font_sizes %{xs: "text-xs", sm: "text-sm", md: "text-sm font-medium", lg: "text-base"}
  @click_animation %{
    xs: "active:enabled:scale-[0.97]",
    sm: "active:enabled:scale-[0.97]",
    md: "active:enabled:scale-[0.98]",
    lg: "active:enabled:scale-[0.98]"
  }
  @justify %{start: "justify-start", center: "justify-center", end: "justify-end"}

  @doc """
  `components-next/button/Button.vue`. Ex.:

      <.next_button icon="ph-funnel-simple" color={:slate} variant={:faded} size={:xs} />
  """
  attr :label, :string, default: nil
  attr :icon, :string, default: nil
  attr :trailing_icon, :boolean, default: false
  attr :color, :atom, default: :blue, values: [:blue, :ruby, :amber, :slate, :teal]
  attr :variant, :atom, default: :solid, values: [:solid, :faded, :outline, :ghost, :link]
  attr :size, :atom, default: :md, values: [:xs, :sm, :md, :lg]
  attr :justify, :atom, default: :center, values: [:start, :center, :end]
  attr :no_animation, :boolean, default: false
  attr :type, :string, default: "button"
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled form name value title aria-label)
  slot :inner_block

  def next_button(assigns) do
    icon_only? = is_nil(assigns.label) and assigns.inner_block == []
    variant = Map.fetch!(@colors[assigns.color], assigns.variant)

    size_classes =
      cond do
        assigns.variant == :link -> "p-0"
        icon_only? -> @sizes.icon_only[assigns.size]
        true -> @sizes.regular[assigns.size]
      end

    assigns =
      assign(assigns,
        classes: [
          "inline-flex items-center min-w-0 gap-2 transition-all duration-100 ease-out border-0 rounded-lg outline-1 outline disabled:opacity-50",
          variant,
          assigns.variant == :link && "font-medium underline-offset-2",
          size_classes,
          @font_sizes[assigns.size],
          !assigns.no_animation && @click_animation[assigns.size],
          @justify[assigns.justify],
          assigns.trailing_icon && !icon_only? && "flex-row-reverse",
          assigns.class
        ]
      )

    ~H"""
    <button type={@type} class={@classes} {@rest}>
      <span :if={@icon} class={[@icon, "flex-shrink-0"]} />
      <span :if={@label} class="min-w-0 truncate">{@label}</span>
      {render_slot(@inner_block)}
    </button>
    """
  end
end
