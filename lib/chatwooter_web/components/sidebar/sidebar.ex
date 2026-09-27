defmodule ChatwooterWeb.Components.Sidebar.Sidebar do
  @moduledoc """
  Sidebar do app — port 1:1 de `chatwoot/app/javascript/dashboard/components-next/sidebar/Sidebar.vue`
  (classes copiadas dos `.vue`). Estado e rotas vêm de `ChatwooterWeb.Sidebar` (on_mount).
  """
  use ChatwooterWeb, :component

  import ChatwooterWeb.Components.Sidebar.{
    AccountSwitcher,
    Collapsed,
    Group,
    MobileLauncher,
    ProfileMenu
  }

  alias ChatwooterWeb.Sidebar

  attr :current_scope, :map, required: true
  attr :sidebar, :map, required: true

  def sidebar(assigns) do
    menu = Sidebar.menu(assigns.sidebar)
    uri = assigns.sidebar.uri

    assigns =
      assigns
      |> assign(:menu, menu)
      |> assign(:active_leaf, Sidebar.active_leaf(menu, uri))
      |> assign(:current_path, uri && uri.path)
      |> assign(:collapsed, Sidebar.collapsed?(assigns.sidebar))
      |> assign(:conversation_open?, conversation_open?(uri))

    ~H"""
    <aside
      id="app-sidebar"
      phx-hook=".SidebarShell"
      data-collapsed={to_string(@collapsed)}
      data-mobile-open="false"
      style={"--sidebar-width: #{@sidebar.width}px"}
      class="group/sidebar peer bg-n-background flex flex-col text-sm pb-px fixed top-0 left-0 h-full z-40 w-[200px] md:w-(--sidebar-width) md:relative md:flex-shrink-0 md:translate-x-0 border-r border-n-weak -translate-x-full data-[mobile-open=true]:translate-x-0 data-[mobile-open=true]:shadow-lg md:data-[mobile-open=true]:shadow-none transition-transform duration-200 ease-out md:transition-[width] data-[resizing=true]:transition-none"
    >
      <section class={["grid", if(@collapsed, do: "mt-3 mb-6 gap-4", else: "mt-1 mb-4 gap-2")]}>
        <div class={[
          "flex gap-2 items-center min-w-0",
          if(@collapsed, do: "justify-center px-1", else: "px-2")
        ]}>
          <%= if @collapsed do %>
            <.sidebar_account_switcher sidebar={@sidebar} />
          <% else %>
            <div class="grid flex-shrink-0 place-content-center size-6">
              <.sidebar_logo />
            </div>
            <div class="flex-shrink-0 w-px h-3 bg-n-strong" />
            <button
              id="sidebar-account-switcher"
              type="button"
              class="flex items-center gap-2 justify-between w-full rounded-lg px-2 cursor-default flex-grow -mx-1 min-w-0"
            >
              <span class="text-sm font-medium leading-5 text-n-slate-12 truncate" aria-live="polite">
                {@sidebar.account && @sidebar.account.name}
              </span>
            </button>
          <% end %>
        </div>
        <div class={["flex gap-2", if(@collapsed, do: "flex-col items-center", else: "px-2")]}>
          <%!-- Busca global e "nova conversa" ainda não existem; ficam só visuais por ora --%>
          <button
            :if={!@collapsed}
            id="sidebar-search"
            type="button"
            class="flex gap-2 items-center px-2 py-1 w-full h-7 rounded-lg outline outline-1 outline-n-weak bg-n-button-color transition-all duration-100 ease-out"
          >
            <span class="flex-shrink-0 ph-magnifying-glass size-4 text-n-slate-10" />
            <span class="flex-grow text-start text-n-slate-10">Search...</span>
          </button>
          <button
            :if={@collapsed}
            id="sidebar-search"
            type="button"
            title="Search..."
            class="flex items-center justify-center size-8 rounded-lg outline outline-1 outline-n-weak bg-n-button-color transition-all duration-100 ease-out hover:bg-n-alpha-2 dark:hover:bg-n-slate-9/30"
          >
            <span class="ph-magnifying-glass size-4 text-n-slate-11" />
          </button>
          <button
            id="sidebar-compose"
            type="button"
            title="New conversation"
            class={[
              "inline-flex items-center justify-center min-w-0 gap-2 transition-all duration-100 ease-out border-0 rounded-lg outline-1 outline bg-n-button-color hover:enabled:bg-n-alpha-2 dark:hover:enabled:bg-n-slate-9/30 p-0 text-sm active:enabled:scale-[0.97] outline-n-weak text-n-slate-11 shrink-0",
              if(@collapsed, do: "size-8", else: "w-8 h-7")
            ]}
          >
            <span class="ph-note-pencil size-4" />
          </button>
        </div>
      </section>

      <nav class={[
        "grid overflow-y-scroll flex-grow gap-2 pb-5 no-scrollbar min-w-0",
        if(@collapsed, do: "px-1", else: "px-2")
      ]}>
        <ul class={["flex flex-col gap-1 m-0 list-none min-w-0", @collapsed && "items-center"]}>
          <%= for group <- @menu do %>
            <.sidebar_collapsed_group :if={@collapsed} group={group} active_leaf={@active_leaf} />
            <.sidebar_group
              :if={!@collapsed}
              group={group}
              active_leaf={@active_leaf}
              current_path={@current_path}
              account_id={@sidebar.account && @sidebar.account.id}
            />
          <% end %>
        </ul>
      </nav>

      <%!-- Fora do <nav> para não ser cortado pelo overflow dele --%>
      <%= if @collapsed do %>
        <.sidebar_collapsed_popover
          :for={group <- @menu}
          group={group}
          active_leaf={@active_leaf}
          current_path={@current_path}
        />
      <% end %>

      <section class="flex relative flex-col flex-shrink-0 gap-1 justify-between items-center">
        <div class="pointer-events-none absolute inset-x-0 -top-[1.938rem] h-8 bg-linear-to-t from-n-background to-transparent" />
        <div class={[
          "px-1 py-1.5 flex-shrink-0 flex w-full z-50 gap-2 items-center border-t border-n-weak shadow-sidebar-profile",
          if(@collapsed, do: "justify-center", else: "justify-between")
        ]}>
          <.sidebar_profile_menu
            user={@current_scope.user}
            availability={@sidebar.availability}
            auto_offline={@sidebar.auto_offline}
            collapsed={@collapsed}
          />
        </div>
      </section>

      <div
        data-resize-handle
        class="hidden md:block absolute top-0 h-full w-1 cursor-col-resize z-40 right-0 group"
      >
        <div class="absolute top-0 h-full w-px right-0 bg-transparent group-hover:bg-n-brand transition-colors group-data-[resizing=true]/sidebar:bg-n-brand" />
      </div>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".SidebarShell">
        const MIN_WIDTH = 56
        const MAX_WIDTH = 320
        const COLLAPSED_THRESHOLD = 160
        const clientX = e => (e.touches ? e.touches[0].clientX : e.clientX)

        export default {
          mounted() {
            this.cleanups = []
            this.setupResize()
            this.setupViewport()
            this.setupMobile()
            this.setupPopovers()
          },

          destroyed() {
            clearTimeout(this.closeTimer)
            this.cleanups.forEach(fn => fn())
          },

          listen(target, event, handler, opts) {
            target.addEventListener(event, handler, opts)
            this.cleanups.push(() => target.removeEventListener(event, handler, opts))
          },

          // Sidebar.vue: onResizeStart / onResizeMove / onResizeEnd / dblclick
          setupResize() {
            const onStart = e => {
              if (!e.target.closest("[data-resize-handle]")) return
              this.resizing = true
              this.startX = clientX(e)
              this.startWidth = this.el.getBoundingClientRect().width
              this.width = this.startWidth
              this.closePopover()
              this.js().setAttribute(this.el, "data-resizing", "true")
              Object.assign(document.body.style, {cursor: "col-resize", userSelect: "none"})
              e.preventDefault()
            }
            const onMove = e => {
              if (!this.resizing) return
              this.width = Math.max(MIN_WIDTH, Math.min(MAX_WIDTH, this.startWidth + clientX(e) - this.startX))
              this.el.style.setProperty("--sidebar-width", `${this.width}px`)
              const collapsed = this.width < COLLAPSED_THRESHOLD
              if (collapsed !== (this.el.dataset.collapsed === "true")) {
                this.pushEventTo(this.el, "sidebar:resize", {width: this.width})
              }
            }
            const onEnd = () => {
              if (!this.resizing) return
              this.resizing = false
              this.js().removeAttribute(this.el, "data-resizing")
              Object.assign(document.body.style, {cursor: "", userSelect: ""})
              this.pushEventTo(this.el, "sidebar:resize", {width: this.width, save: true})
            }

            this.listen(this.el, "mousedown", onStart)
            this.listen(this.el, "touchstart", onStart, {passive: false})
            this.listen(document, "mousemove", onMove)
            this.listen(document, "touchmove", onMove, {passive: false})
            this.listen(document, "mouseup", onEnd)
            this.listen(document, "touchend", onEnd)
            this.listen(this.el, "dblclick", e => {
              if (e.target.closest("[data-resize-handle]")) this.pushEventTo(this.el, "sidebar:toggle_collapse", {})
            })
          },

          // No mobile a sidebar é sempre expandida (isEffectivelyCollapsed)
          setupViewport() {
            const query = matchMedia("(max-width: 767px)")
            const push = () => this.pushEventTo(this.el, "sidebar:viewport", {mobile: query.matches})
            if (query.matches) push()
            this.listen(query, "change", push)
          },

          // Flyout mobile: o launcher dispara "sidebar:toggle-mobile"; clique fora fecha
          setupMobile() {
            const setOpen = open => this.js().setAttribute(this.el, "data-mobile-open", String(open))
            this.listen(this.el, "sidebar:toggle-mobile", () => setOpen(this.el.dataset.mobileOpen !== "true"))
            this.listen(document, "click", e => {
              if (this.el.dataset.mobileOpen !== "true") return
              if (this.el.contains(e.target) || e.target.closest("#mobile-sidebar-launcher")) return
              setOpen(false)
            })
          },

          // SidebarGroup (recolhida): popover no hover, fecha com atraso (usePopoverState)
          setupPopovers() {
            this.listen(this.el, "mouseover", e => {
              const trigger = e.target.closest("[data-popover-trigger]")
              if (trigger) return this.openPopover(trigger)
              if (e.target.closest("[data-popover]")) clearTimeout(this.closeTimer)
            })
            this.listen(this.el, "mouseout", e => {
              const from = e.target.closest("[data-popover-trigger], [data-popover]")
              if (!from || (e.relatedTarget && from.contains(e.relatedTarget))) return
              this.scheduleClose(from.hasAttribute("data-popover") ? 100 : 200)
            })
            this.listen(this.el, "click", e => {
              if (e.target.closest("[data-popover] a")) this.closePopover()
            })
            this.listen(window, "blur", () => this.closePopover())
            this.listen(document, "mouseleave", () => this.closePopover())
          },

          openPopover(trigger) {
            if (this.resizing) return
            clearTimeout(this.closeTimer)
            const popover = this.el.querySelector(`[data-popover="${trigger.dataset.popoverTrigger}"]`)
            if (!popover || popover === this.activePopover) return
            this.closePopover()

            this.js().removeAttribute(popover, "hidden")
            const aside = this.el.getBoundingClientRect()
            const {top} = trigger.getBoundingClientRect()
            const height = popover.offsetHeight || 300
            const viewportTop = top + height > window.innerHeight - 20
              ? Math.max(20, window.innerHeight - height - 20)
              : top
            this.js().setAttribute(popover, "style", `top: ${viewportTop - aside.top}px; left: ${aside.width + 8}px`)
            this.activePopover = popover
          },

          scheduleClose(delay) {
            clearTimeout(this.closeTimer)
            this.closeTimer = setTimeout(() => this.closePopover(), delay)
          },

          closePopover() {
            clearTimeout(this.closeTimer)
            if (this.activePopover) this.js().setAttribute(this.activePopover, "hidden", "")
            this.activePopover = null
          }
        }
      </script>
    </aside>

    <.mobile_sidebar_launcher :if={!@conversation_open?} />
    """
  end

  # MobileSidebarLauncher.vue: some com uma conversa aberta (CONVERSATION_ROUTES)
  defp conversation_open?(nil), do: false

  defp conversation_open?(%URI{query: query}),
    do: Map.has_key?(URI.decode_query(query || ""), "conversation_id")
end
