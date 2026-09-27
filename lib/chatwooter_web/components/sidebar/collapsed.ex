defmodule ChatwooterWeb.Components.Sidebar.Collapsed do
  @moduledoc """
  Sidebar recolhida: `SidebarGroup.vue` (ramo isCollapsed) + `SidebarCollapsedPopover.vue`.
  """
  use ChatwooterWeb, :component

  alias ChatwooterWeb.Sidebar

  attr :group, :map, required: true
  attr :active_leaf, :string, default: nil

  # SidebarGroup.vue, ramo isCollapsed: só o ícone; os filhos vão no popover
  def sidebar_collapsed_group(assigns) do
    leaves = Sidebar.leaves(assigns.group)

    assigns =
      assigns
      |> assign(:active_child?, Enum.any?(leaves, &(&1.name == assigns.active_leaf)))
      |> assign(:first_leaf, List.first(leaves))

    ~H"""
    <li
      id={"sidebar-group-#{@group.name}"}
      class="grid gap-1 text-sm cursor-pointer select-none min-w-0"
    >
      <.link
        navigate={@first_leaf && @first_leaf.to}
        data-popover-trigger={@group.name}
        title={@group.label}
        class={[
          "flex items-center justify-center size-10 rounded-lg",
          if(@active_child?,
            do: "text-n-slate-12 bg-n-alpha-2",
            else: "text-n-slate-11 hover:bg-n-alpha-2"
          )
        ]}
      >
        <.icon name={@group.icon} class="size-4" />
      </.link>
    </li>
    """
  end

  attr :group, :map, required: true
  attr :active_leaf, :string, default: nil
  attr :current_path, :string, default: nil

  # SidebarCollapsedPopover.vue; posição calculada pelo hook .SidebarShell
  def sidebar_collapsed_popover(assigns) do
    assigns = assign(assigns, :children, Sidebar.visible_children(assigns.group))

    ~H"""
    <div
      id={"sidebar-popover-#{@group.name}"}
      data-popover={@group.name}
      class="absolute z-[100] min-w-[200px] max-w-[280px]"
      hidden
    >
      <div class="bg-n-alpha-3 backdrop-blur-[100px] outline outline-1 -outline-offset-1 w-56 outline-n-weak rounded-xl shadow-lg py-2 px-2">
        <div class="px-2 py-1.5 text-xs font-medium text-n-slate-11 uppercase tracking-wider border-b border-n-weak mb-1">
          {@group.label}
        </div>
        <ul class="m-0 p-0 list-none max-h-[400px] overflow-y-auto no-scrollbar">
          <%= for child <- @children do %>
            <li
              :if={Map.has_key?(child, :children)}
              id={"sidebar-popover-section-#{child.name}"}
              data-open={to_string(Enum.any?(child.children, &(&1.name == @active_leaf)))}
              class="group/popsection py-0.5"
            >
              <div class="flex items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 transition-colors duration-150 ease-out">
                <button
                  type="button"
                  phx-click={toggle_popover_section(child.name)}
                  class="flex flex-1 min-w-0 items-center gap-2 ps-2 py-1.5 text-left"
                >
                  <.icon :if={child[:icon]} name={child.icon} class="size-4 flex-shrink-0" />
                  <span class="flex-1 truncate text-sm">{child.label}</span>
                </button>
                <div class="flex flex-shrink-0 items-center gap-1 pe-2">
                  <button
                    type="button"
                    aria-label={child.label}
                    phx-click={toggle_popover_section(child.name)}
                    class="flex size-6 flex-shrink-0 items-center justify-center rounded-md text-n-slate-11 hover:bg-n-alpha-2 focus-visible:bg-n-alpha-2 focus-visible:outline-none"
                  >
                    <span class="size-4 flex-shrink-0 transition-transform ph-caret-down group-data-[open=true]/popsection:rotate-180" />
                  </button>
                </div>
              </div>
              <ul class="m-0 p-0 list-none pl-4 mt-1 overflow-hidden hidden group-data-[open=true]/popsection:block">
                <li :for={leaf <- child.children} class="py-0.5">
                  <.popover_link
                    leaf={leaf}
                    active={leaf.name == @active_leaf}
                    current_path={@current_path}
                  />
                </li>
              </ul>
            </li>
            <li :if={!Map.has_key?(child, :children)} class="py-0.5">
              <.popover_link
                leaf={child}
                active={child.name == @active_leaf}
                current_path={@current_path}
              />
            </li>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end

  attr :leaf, :map, required: true
  attr :active, :boolean, default: false
  attr :current_path, :string, default: nil

  defp popover_link(assigns) do
    assigns = assign(assigns, :nav, Sidebar.leaf_nav(assigns.leaf.to, assigns.current_path))

    ~H"""
    <.link
      {@nav}
      aria-current={@active && "page"}
      class={[
        "flex items-center gap-2 px-2 py-1.5 w-full rounded-lg text-sm text-left transition-colors duration-150 ease-out",
        if(@active, do: "text-n-slate-12 bg-n-alpha-2", else: "text-n-slate-11 hover:bg-n-alpha-2")
      ]}
    >
      <.channel_icon :if={@leaf[:inbox]} inbox={@leaf.inbox} class="size-4 flex-shrink-0" />
      <.icon :if={!@leaf[:inbox] && @leaf[:icon]} name={@leaf.icon} class="size-4 flex-shrink-0" />
      <span class="flex-1 truncate">{@leaf.label}</span>
    </.link>
    """
  end

  defp toggle_popover_section(name) do
    JS.toggle_attribute({"data-open", "true", "false"}, to: "#sidebar-popover-section-#{name}")
  end
end
