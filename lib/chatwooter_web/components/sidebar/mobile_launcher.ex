defmodule ChatwooterWeb.Components.Sidebar.MobileLauncher do
  @moduledoc """
  Port de `sidebar/MobileSidebarLauncher.vue`.
  """
  use ChatwooterWeb, :component

  def mobile_sidebar_launcher(assigns) do
    ~H"""
    <div
      id="mobile-sidebar-launcher"
      class="fixed bottom-4 left-4 z-40 transition-transform duration-200 ease-out block md:hidden peer-data-[mobile-open=true]:translate-x-48"
    >
      <div class="inline-flex rounded-full bg-n-alpha-2 backdrop-blur-lg p-1 shadow hover:shadow-md">
        <button
          type="button"
          aria-label="Toggle sidebar"
          phx-click={JS.dispatch("sidebar:toggle-mobile", to: "#app-sidebar")}
          class="inline-flex items-center justify-center min-w-0 border-0 outline-1 outline outline-transparent size-10 p-0 rounded-full bg-n-solid-3 dark:bg-n-alpha-2 text-n-slate-12 text-xl transition-all duration-200 ease-out hover:brightness-110"
        >
          <span class="ph-list size-5" />
        </button>
      </div>
    </div>
    """
  end
end
