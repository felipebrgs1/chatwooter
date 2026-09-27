defmodule ChatwooterWeb.Components.Sidebar.AccountSwitcher do
  @moduledoc """
  Port de `sidebar/SidebarAccountSwitcher.vue` (modo recolhido) e do logo do topo.
  """
  use ChatwooterWeb, :component

  attr :sidebar, :map, required: true

  # SidebarAccountSwitcher.vue, modo recolhido: o logo abre a lista de contas
  def sidebar_account_switcher(assigns) do
    ~H"""
    <div
      id="sidebar-account-menu"
      class="relative space-y-2"
      phx-click-away={close_dropdown("sidebar-account-menu")}
    >
      <button
        id="sidebar-account-menu-trigger"
        type="button"
        title={@sidebar.account && @sidebar.account.name}
        phx-click={toggle_dropdown("sidebar-account-menu")}
        class="grid flex-shrink-0 place-content-center p-2 rounded-lg cursor-pointer hover:bg-n-alpha-1"
      >
        <.sidebar_logo class="size-7" icon_class="size-4" />
      </button>
      <div id="sidebar-account-menu-body" class="absolute" hidden>
        <div class="absolute min-w-80 z-50">
          <ul class="text-sm bg-n-alpha-3 backdrop-blur-[100px] border rounded-xl shadow-sm py-2 gap-2 grid list-none px-2 relative border-n-weak">
            <div class="-mx-2">
              <div class="px-4 mb-3 mt-1 leading-4 font-medium tracking-[0.2px] text-n-slate-10 text-xs">
                Switch account
              </div>
              <ul class="gap-2 grid list-none px-2 overflow-y-auto max-h-96">
                <li :for={membership <- @sidebar.memberships} id={"account-#{membership.account_id}"}>
                  <div class="flex text-left items-center p-2 text-sm text-n-slate-12 w-full border-0 hover:bg-n-alpha-2 rounded-lg gap-3 cursor-pointer">
                    <div class="text-left flex gap-2 items-center">
                      <span
                        class="text-n-slate-12 max-w-36 truncate min-w-0"
                        title={membership.account.name}
                      >
                        {membership.account.name}
                      </span>
                      <div class="flex-shrink-0 w-px h-3 bg-n-strong" />
                      <span class="text-n-slate-11 max-w-24 truncate capitalize">
                        {membership.role}
                      </span>
                    </div>
                    <span
                      :if={@sidebar.account && membership.account_id == @sidebar.account.id}
                      class="ph-check text-n-teal-11 size-5"
                    />
                  </div>
                </li>
              </ul>
            </div>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  attr :class, :string, default: "size-4"
  attr :icon_class, :string, default: "size-2.5"

  def sidebar_logo(assigns) do
    ~H"""
    <span class={["grid place-content-center rounded-full bg-n-brand", @class]}>
      <span class={["ph-chat-circle text-white", @icon_class]} />
    </span>
    """
  end
end
