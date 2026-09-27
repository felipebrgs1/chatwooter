defmodule ChatwooterWeb.Components.Next.Avatar do
  @moduledoc "Port de `components-next/avatar/Avatar.vue` + helpers de nome/iniciais."
  use ChatwooterWeb, :base_component

  # Avatar.vue: cor pelo tamanho do nome (AVATAR_COLORS), tokens em tokens.css
  @avatar_colors [
    "bg-avatar-0-bg text-avatar-0-text",
    "bg-avatar-1-bg text-avatar-1-text",
    "bg-avatar-2-bg text-avatar-2-text",
    "bg-avatar-3-bg text-avatar-3-text",
    "bg-avatar-4-bg text-avatar-4-text",
    "bg-avatar-5-bg text-avatar-5-text"
  ]

  @status_colors %{online: "bg-n-teal-10", busy: "bg-n-amber-10", offline: "bg-n-slate-10"}

  attr :name, :string, default: nil
  attr :size, :integer, default: 32
  attr :status, :atom, default: nil
  attr :class, :any, default: nil

  def avatar(assigns) do
    size = assigns.size
    badge = max(size * 0.35, 8)

    assigns =
      assigns
      |> assign(:color, avatar_color(assigns.name))
      |> assign(:radius, avatar_radius(size))
      |> assign(
        :badge_style,
        "width:#{badge}px;height:#{badge}px;top:#{size - badge / 1.1}px;left:#{size - badge / 1.1}px"
      )
      |> assign(:status_color, @status_colors[assigns.status])

    ~H"""
    <span
      class={["relative inline-flex group/avatar z-0 flex-shrink-0 align-middle", @class]}
      style={"width:#{@size}px;height:#{@size}px"}
    >
      <span
        :if={@status_color}
        data-status={@status}
        class={["absolute z-20 border rounded-full border-n-slate-3", @status_color]}
        style={@badge_style}
      />
      <span
        role="img"
        class={[
          "relative inline-flex items-center justify-center object-cover overflow-hidden font-medium outline outline-1 -outline-offset-1 outline-black/3 dark:outline-white/4",
          @radius,
          @color || "bg-n-slate-3 dark:bg-n-slate-4"
        ]}
        style={"width:#{@size}px;height:#{@size}px"}
      >
        <span :if={@color} class="select-none" style={"font-size:#{min(@size / 2.5, 24)}px"}>
          {initials(@name)}
        </span>
        <span :if={!@color} class="ph-user" style={"font-size:#{@size / 1.6}px"} />
      </span>
    </span>
    """
  end

  defp avatar_color(name) when name in [nil, ""], do: nil

  defp avatar_color(name),
    do: Enum.at(@avatar_colors, rem(String.length(name), length(@avatar_colors)))

  defp avatar_radius(size) when size <= 16, do: "rounded"
  defp avatar_radius(size) when size <= 24, do: "rounded-md"
  defp avatar_radius(size) when size <= 32, do: "rounded-lg"
  defp avatar_radius(size) when size <= 48, do: "rounded-xl"
  defp avatar_radius(_size), do: "rounded-2xl"

  @doc "`available_name` do Chatwoot: display_name, senão name; aqui caímos no e-mail."
  def available_name(%{display_name: name}) when name not in [nil, ""], do: name
  def available_name(%{name: name}) when name not in [nil, ""], do: name
  def available_name(%{email: email}), do: email

  def initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end
end
