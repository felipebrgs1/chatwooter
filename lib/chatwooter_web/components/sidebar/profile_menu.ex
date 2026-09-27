defmodule ChatwooterWeb.Components.Sidebar.ProfileMenu do
  @moduledoc """
  Port de `sidebar/SidebarProfileMenu.vue` + `SidebarProfileMenuStatus.vue`.
  """
  use ChatwooterWeb, :component

  @availabilities [
    %{value: :online, label: "Online", color: "bg-n-teal-9"},
    %{value: :busy, label: "Busy", color: "bg-n-amber-9"},
    %{value: :offline, label: "Offline", color: "bg-n-slate-9"}
  ]

  attr :user, :map, required: true
  attr :availability, :atom, required: true
  attr :auto_offline, :boolean, required: true
  attr :collapsed, :boolean, default: false

  # SidebarProfileMenu + SidebarProfileMenuStatus
  def sidebar_profile_menu(assigns) do
    assigns =
      assigns
      |> assign(:name, available_name(assigns.user))
      |> assign(:availabilities, @availabilities)
      |> assign(:active_status, Enum.find(@availabilities, &(&1.value == assigns.availability)))

    ~H"""
    <div
      id="sidebar-profile-menu"
      class={["relative space-y-2 min-w-0", if(@collapsed, do: "w-auto", else: "w-full")]}
      phx-click-away={close_dropdown("sidebar-profile-menu")}
    >
      <button
        id="sidebar-profile-menu-trigger"
        type="button"
        title={@collapsed && @name}
        class={[
          "flex gap-2 items-center p-1 text-left rounded-lg cursor-pointer hover:bg-n-alpha-1",
          if(@collapsed, do: "justify-center", else: "w-full")
        ]}
        phx-click={toggle_dropdown("sidebar-profile-menu")}
      >
        <.avatar name={@name} size={32} status={@availability} />
        <div :if={!@collapsed} class="min-w-0">
          <div class="text-sm font-medium leading-4 truncate text-n-slate-12">{@name}</div>
          <div class="text-xs truncate text-n-slate-11">{@user.email}</div>
        </div>
      </button>
      <div id="sidebar-profile-menu-body" class="absolute" hidden>
        <div class="absolute bottom-12 z-50 mb-2 w-80 left-0">
          <ul class="text-sm bg-n-alpha-3 backdrop-blur-[100px] border rounded-xl shadow-sm py-2 gap-2 grid list-none px-2 relative border-n-weak">
            <div class="-mx-2">
              <ul class="gap-2 grid list-none px-2 max-h-96 overflow-visible">
                <div class="grid gap-0">
                  <li>
                    <div class="flex text-left items-center p-2 text-sm text-n-slate-12 w-full border-0 gap-1">
                      <div class="flex-grow flex items-center gap-1 min-w-0">
                        Set your availability
                      </div>
                      <div
                        id="sidebar-availability-menu"
                        class="relative space-y-2 shrink-0"
                        phx-click-away={close_dropdown("sidebar-availability-menu")}
                      >
                        <button
                          id="sidebar-availability-menu-trigger"
                          type="button"
                          phx-click={toggle_dropdown("sidebar-availability-menu")}
                          class="inline-flex items-center min-w-0 gap-2 transition-all duration-100 ease-out border-0 rounded-lg outline-1 outline bg-n-slate-9/10 text-n-slate-12 hover:enabled:bg-n-slate-9/20 focus-visible:bg-n-slate-9/20 outline-transparent h-8 px-3 text-sm active:enabled:scale-[0.97]"
                        >
                          <div class="flex gap-1 items-center min-w-0 text-sm">
                            <div class="p-1 flex-shrink-0">
                              <div class={["size-2 rounded-sm", @active_status.color]} />
                            </div>
                            <span class="truncate max-w-[7rem]">{@active_status.label}</span>
                          </div>
                          <span class="ph-caret-down size-4 flex-shrink-0" />
                        </button>
                        <div id="sidebar-availability-menu-body" class="absolute" hidden>
                          <div class="absolute min-w-32 z-20">
                            <ul class="text-sm bg-n-alpha-3 backdrop-blur-[100px] border rounded-xl shadow-sm py-2 gap-2 grid list-none px-2 relative border-n-weak">
                              <li :for={status <- @availabilities}>
                                <button
                                  id={"sidebar-availability-#{status.value}"}
                                  type="button"
                                  phx-click={
                                    JS.push("sidebar:set_availability",
                                      value: %{availability: status.value}
                                    )
                                    |> close_dropdown("sidebar-availability-menu")
                                  }
                                  class="flex text-left items-center p-2 text-sm text-n-slate-12 w-full border-0 hover:bg-n-alpha-2 rounded-lg gap-3 cursor-pointer"
                                >
                                  <span class={[status.color, "size-[12px] rounded"]} />
                                  {status.label}
                                </button>
                              </li>
                            </ul>
                          </div>
                        </div>
                      </div>
                    </div>
                  </li>
                  <li>
                    <div class="flex text-left items-center p-2 text-sm text-n-slate-12 w-full border-0">
                      <div class="flex-grow min-w-0">
                        Mark offline automatically
                        <span
                          title="Automatically mark offline when you aren't using the app."
                          class="ph-info inline-block align-middle ms-1 size-4 text-n-slate-10"
                        />
                      </div>
                      <.next_switch
                        id="sidebar-auto-offline"
                        checked={@auto_offline}
                        phx-click="sidebar:toggle_auto_offline"
                      />
                    </div>
                  </li>
                </div>
              </ul>
            </div>
            <div class="h-0 border-b border-n-strong -mx-2" />
            <li>
              <.link
                navigate={~p"/app/settings/profile"}
                class="flex text-left items-center p-2 text-sm text-n-slate-12 w-full border-0 hover:bg-n-alpha-2 rounded-lg gap-3"
              >
                <span class="ph-user-gear size-4 text-n-slate-11" /> Profile settings
              </.link>
            </li>
            <li>
              <.link
                href={~p"/app/logout"}
                method="delete"
                class="flex text-left items-center p-2 text-sm text-n-slate-12 w-full border-0 hover:bg-n-alpha-2 rounded-lg gap-3"
              >
                <span class="ph-power size-4 text-n-slate-11" /> Log out
              </.link>
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end
