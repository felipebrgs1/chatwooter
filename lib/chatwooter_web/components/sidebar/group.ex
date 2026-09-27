defmodule ChatwooterWeb.Components.Sidebar.Group do
  @moduledoc """
  Sidebar expandida: `SidebarGroup`, `SidebarGroupHeader`, `SidebarGroupLeaf`,
  `SidebarSubGroup` e `SidebarGroupSeparator`.
  """
  use ChatwooterWeb, :component

  alias ChatwooterWeb.Sidebar

  # Conectores da árvore (SidebarGroupLeaf / SidebarSubGroup / SidebarGroupSeparator)
  @tree_connector "child-item before:content-[''] before:absolute before:start-0 before:w-0.5 before:h-full before:bg-n-slate-4 first:before:rounded-t last:before:h-1/5 last:after:content-[''] last:after:absolute last:after:start-0 last:after:bottom-[calc(50%_-_2px)] last:after:h-3 last:after:w-2.5 last:after:border-b-2 last:after:border-s-2 last:after:rounded-es last:after:border-n-slate-4"
  @thin_tree_line "before:w-px! last:after:border-b! last:after:border-s!"
  @children_trunk "before:content-[''] before:absolute before:top-0 before:bottom-0 before:w-0.5 before:bg-n-slate-4 before:start-[-0.5rem]"
  @tree_vertical_line "before:content-[''] before:absolute before:-top-1 before:w-0.5 before:bg-n-slate-4 before:start-[-0.5rem]"
  @tree_elbow "after:content-[''] after:absolute after:w-2.5 after:h-3 after:bottom-1/2 after:start-[-0.5rem] after:border-b-2 after:border-s-2 after:rounded-es after:border-n-slate-4"

  # Subgrupos com mais itens que isso viram lista rolável (SidebarSubGroup.isScrollable)
  @scroll_threshold 7

  attr :group, :map, required: true
  attr :active_leaf, :string, default: nil
  attr :current_path, :string, default: nil
  attr :account_id, :integer, default: nil

  def sidebar_group(assigns) do
    group = assigns.group
    leaves = Sidebar.leaves(group)
    active_child? = Enum.any?(leaves, &(&1.name == assigns.active_leaf))
    visible = Sidebar.visible_children(group)

    assigns =
      assigns
      |> assign(:id, "sidebar-group-#{group.name}")
      |> assign(:active_child?, active_child?)
      |> assign(:first_leaf, List.first(leaves))
      |> assign(:visible, visible)
      |> assign(:last_visible, List.last(visible))

    ~H"""
    <li
      id={@id}
      data-expanded={to_string(@active_child?)}
      class="group/nav grid gap-1 text-sm cursor-pointer select-none min-w-0"
    >
      <.group_header
        id={@id}
        group={@group}
        active_child?={@active_child?}
        first_leaf={@first_leaf}
      />
      <ul class={[
        "m-0 list-none min-w-0",
        if(@active_child?, do: "grid", else: "hidden group-data-[expanded=true]/nav:grid")
      ]}>
        <%= for child <- @visible do %>
          <.nav_subgroup
            :if={Map.has_key?(child, :children)}
            parent={@group.name}
            subgroup={child}
            end_tree_line={child[:tree_line] == true and child == @last_visible}
            active_leaf={@active_leaf}
            current_path={@current_path}
            account_id={@account_id}
          />
          <.nav_leaf
            :if={!Map.has_key?(child, :children)}
            leaf={child}
            active={child.name == @active_leaf}
            current_path={@current_path}
          />
        <% end %>
      </ul>
    </li>
    """
  end

  attr :id, :string, required: true
  attr :group, :map, required: true
  attr :active_child?, :boolean, required: true
  attr :first_leaf, :map, default: nil

  # SidebarGroupHeader: no grupo ativo o clique só expande/recolhe; nos demais
  # navega para o primeiro filho (SidebarGroup.toggleTrigger).
  defp group_header(assigns) do
    ~H"""
    <%= if @active_child? do %>
      <button
        type="button"
        title={@group.label}
        phx-click={JS.toggle_attribute({"data-expanded", "true", "false"}, to: "##{@id}")}
        class="flex items-center gap-2 px-1.5 py-1 rounded-lg h-8 min-w-0 text-n-slate-12 font-medium"
      >
        <.group_header_content group={@group} active_child?={@active_child?} />
        <span class="ph-caret-up size-3 hidden group-data-[expanded=true]/nav:inline-block" />
      </button>
    <% else %>
      <.link
        navigate={@first_leaf && @first_leaf.to}
        title={@group.label}
        draggable="false"
        class="flex items-center gap-2 px-1.5 py-1 rounded-lg h-8 min-w-0 text-n-slate-11 hover:bg-n-alpha-2"
      >
        <.group_header_content group={@group} active_child?={@active_child?} />
      </.link>
    <% end %>
    """
  end

  attr :group, :map, required: true
  attr :active_child?, :boolean, required: true

  defp group_header_content(assigns) do
    ~H"""
    <div class="relative flex items-center gap-2">
      <.icon name={@group.icon} class="size-4" />
    </div>
    <div class="flex items-center gap-1.5 flex-grow justify-between min-w-0 flex-1">
      <span class={["truncate text-start text-body-main", @active_child? && "font-medium text-sm"]}>
        {@group.label}
      </span>
    </div>
    """
  end

  attr :leaf, :map, required: true
  attr :active, :boolean, default: false
  attr :current_path, :string, default: nil
  attr :in_subgroup, :boolean, default: false

  # SidebarGroupLeaf: fora do subgrupo, com o grupo recolhido só a folha ativa aparece.
  defp nav_leaf(assigns) do
    assigns = assign(assigns, :nav, Sidebar.leaf_nav(assigns.leaf.to, assigns.current_path))

    ~H"""
    <li class={[
      "py-0.5 ps-2 ms-3 relative text-n-slate-11 min-w-0",
      tree_connector(),
      @in_subgroup && thin_tree_line(),
      @in_subgroup &&
        "group-data-[expanded=false]/nav:before:hidden group-data-[expanded=false]/nav:after:hidden group-data-[minimized=true]/section:hidden!",
      !@active && "hidden group-data-[expanded=true]/nav:block"
    ]}>
      <.link
        id={"sidebar-#{@leaf.name}"}
        {@nav}
        title={@leaf.label}
        aria-current={@active && "page"}
        class={[
          "flex h-8 items-center gap-2 px-2 py-1 rounded-lg hover:bg-linear-to-r from-transparent via-n-slate-3/70 to-n-slate-3/70 group min-w-0",
          @active && "text-n-slate-12 bg-n-alpha-2 active"
        ]}
      >
        <%= if @leaf[:inbox] do %>
          <span class="size-4 grid place-content-center rounded-full">
            <.channel_icon inbox={@leaf.inbox} class="size-4" />
          </span>
          <div class="flex-1 truncate min-w-0">{@leaf.label}</div>
        <% else %>
          <%!-- cor da etiqueta vem do banco (labels.color), por isso o style inline --%>
          <span :if={@leaf[:color]} class="size-4 grid place-content-center rounded-full">
            <span class="size-[8px] rounded-sm" style={"background-color: #{@leaf.color}"} />
          </span>
          <span :if={@leaf[:icon]} class="size-4 grid place-content-center rounded-full">
            <.icon name={@leaf.icon} class="size-4 inline-block" />
          </span>
          <div class="flex-1 truncate min-w-0 text-sm">{@leaf.label}</div>
        <% end %>
      </.link>
    </li>
    """
  end

  attr :parent, :string, required: true
  attr :subgroup, :map, required: true
  attr :end_tree_line, :boolean, default: false
  attr :active_leaf, :string, default: nil
  attr :current_path, :string, default: nil
  attr :account_id, :integer, default: nil

  # SidebarSubGroup + SidebarGroupSeparator. Recolher persiste no localStorage
  # (hook .SidebarSection), como o SIDEBAR_MINIMIZED_SECTIONS do Chatwoot.
  defp nav_subgroup(assigns) do
    subgroup = assigns.subgroup

    assigns =
      assigns
      |> assign(:id, "sidebar-section-#{subgroup.name}")
      |> assign(:collapsible, subgroup[:collapsible] == true)
      |> assign(:tree_line, subgroup[:tree_line] == true)
      |> assign(:scrollable, length(subgroup.children) > @scroll_threshold)

    ~H"""
    <li
      id={@id}
      phx-hook=".SidebarSection"
      data-section={"#{@account_id}:#{@parent}:#{@subgroup.name}"}
      data-minimized="false"
      data-scroll-end="false"
      class="group/section relative flex flex-col list-none min-w-0"
    >
      <div class={[
        "relative min-w-0 my-1 hidden group-data-[expanded=true]/nav:block",
        @collapsible && "ms-5"
      ]}>
        <div
          title={@subgroup.label}
          class={[
            "relative flex h-8 w-full min-w-0 items-center justify-between gap-2 rounded-lg px-2 py-1.5 text-n-slate-10 select-none",
            @tree_line && tree_vertical_line(),
            @tree_line &&
              if(@end_tree_line, do: "before:h-3 #{tree_elbow()}", else: "before:-bottom-1"),
            @collapsible && "cursor-pointer hover:bg-n-alpha-2 pe-8",
            !@collapsible && "pointer-events-none"
          ]}
          phx-click={@collapsible && toggle_section(@id)}
        >
          <div class="inline-flex min-w-0 items-center gap-2">
            <.icon :if={@subgroup[:icon]} name={@subgroup.icon} class="size-4 flex-shrink-0" />
            <span class="flex-grow truncate text-start text-sm font-medium leading-5">
              {@subgroup.label}
            </span>
          </div>
        </div>
        <div
          :if={@collapsible}
          class="absolute end-2 top-1/2 flex -translate-y-1/2 items-center gap-1"
        >
          <button
            type="button"
            aria-label={@subgroup.label}
            phx-click={toggle_section(@id)}
            class="flex size-6 flex-shrink-0 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-alpha-2 focus-visible:bg-n-alpha-2 focus-visible:outline-none"
          >
            <span class="size-3 flex-shrink-0 ph-caret-up group-data-[minimized=true]/section:hidden" />
            <span class="size-3 flex-shrink-0 ph-caret-down hidden group-data-[minimized=true]/section:inline-block" />
          </button>
        </div>
      </div>
      <ul class={[
        "m-0 list-none relative group min-w-0",
        @collapsible && "ms-5",
        @tree_line && !@end_tree_line && children_trunk()
      ]}>
        <div
          data-section-scroll
          class={[
            "min-w-0",
            @scrollable &&
              "group-data-[expanded=true]/nav:max-h-60 group-data-[expanded=true]/nav:overflow-y-scroll no-scrollbar"
          ]}
        >
          <.nav_leaf
            :for={leaf <- @subgroup.children}
            leaf={leaf}
            active={leaf.name == @active_leaf}
            current_path={@current_path}
            in_subgroup
          />
        </div>
        <div
          :if={@scrollable}
          class="absolute bg-linear-to-t from-n-background w-full h-12 to-transparent -bottom-1 pointer-events-none items-end justify-end px-2 hidden group-data-[expanded=true]/nav:flex group-data-[scroll-end=true]/section:hidden! group-data-[minimized=true]/section:hidden!"
        >
          <span class="ph-caret-double-down w-4 h-6 text-n-slate-9 opacity-50 group-hover:opacity-100" />
        </div>
      </ul>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".SidebarSection">
        const STORAGE_KEY = "chatwooter:sidebar-minimized-sections"

        const readMinimized = () => {
          try {
            const value = JSON.parse(localStorage.getItem(STORAGE_KEY))
            return value && typeof value === "object" && !Array.isArray(value) ? value : {}
          } catch (_e) {
            return {}
          }
        }

        const writeMinimized = value => {
          try { localStorage.setItem(STORAGE_KEY, JSON.stringify(value)) } catch (_e) {}
        }

        export default {
          mounted() {
            this.key = this.el.dataset.section
            this.onToggle = () => {
              const minimized = readMinimized()
              if (this.el.dataset.minimized === "true") minimized[this.key] = true
              else delete minimized[this.key]
              writeMinimized(minimized)
            }
            this.el.addEventListener("sidebar:section-toggled", this.onToggle)

            this.scroller = this.el.querySelector("[data-section-scroll]")
            this.onScroll = () => {
              const {scrollHeight, scrollTop, clientHeight} = this.scroller
              const atEnd = Math.abs(scrollHeight - scrollTop - clientHeight) < 1
              this.js().setAttribute(this.el, "data-scroll-end", String(atEnd))
            }
            this.scroller.addEventListener("scroll", this.onScroll)

            this.restore()
          },
          destroyed() {
            this.scroller.removeEventListener("scroll", this.onScroll)
          },
          // Seção com o item ativo sempre abre (SidebarSubGroup.expandSubGroupOnActiveChild)
          restore() {
            const minimized = readMinimized()
            if (!minimized[this.key]) return

            if (this.el.querySelector("[aria-current=page]")) {
              delete minimized[this.key]
              writeMinimized(minimized)
            } else {
              this.js().setAttribute(this.el, "data-minimized", "true")
            }
          }
        }
      </script>
    </li>
    """
  end

  defp toggle_section(id) do
    JS.toggle_attribute({"data-minimized", "true", "false"}, to: "##{id}")
    |> JS.dispatch("sidebar:section-toggled", to: "##{id}")
  end

  defp tree_connector, do: @tree_connector
  defp thin_tree_line, do: @thin_tree_line
  defp children_trunk, do: @children_trunk
  defp tree_vertical_line, do: @tree_vertical_line
  defp tree_elbow, do: @tree_elbow
end
