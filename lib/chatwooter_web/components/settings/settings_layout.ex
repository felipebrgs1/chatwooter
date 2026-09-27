defmodule ChatwooterWeb.Components.Settings.SettingsLayout do
  @moduledoc "Moldura das páginas de Settings: sidebar do app + menu interno (General, Inboxes, Agents, Profile)."
  use ChatwooterWeb, :component

  import ChatwooterWeb.Components.Sidebar.Sidebar

  attr :current_scope, :map, required: true
  attr :sidebar, :map, required: true
  attr :flash, :map, required: true
  attr :active, :atom, required: true, values: [:general, :inboxes, :agents, :profile]
  slot :inner_block, required: true

  def settings_layout(assigns) do
    ~H"""
    <div class="flex h-screen overflow-hidden bg-canvas">
      <.sidebar current_scope={@current_scope} sidebar={@sidebar} />

      <div class="flex min-w-0 flex-1">
        <nav class="w-56 shrink-0 space-y-1 border-r border-line bg-surface p-4">
          <p class="px-3 pb-2 text-xs font-semibold uppercase tracking-wider text-slate-400">
            Settings
          </p>
          <.link
            :for={
              {label, action, path} <- [
                {"General", :general, ~p"/app/settings"},
                {"Inboxes", :inboxes, ~p"/app/settings/inboxes"},
                {"Agents", :agents, ~p"/app/settings/agents"},
                {"Profile", :profile, ~p"/app/settings/profile"}
              ]
            }
            navigate={path}
            class={[
              "block rounded-lg px-3 py-2 text-sm",
              @active == action && "bg-highlight font-semibold text-slate-900",
              @active != action && "text-slate-600 hover:bg-slate-100"
            ]}
          >
            {label}
          </.link>
        </nav>

        <main class="min-w-0 flex-1 overflow-y-auto p-8">
          <ChatwooterWeb.Layouts.flash_group flash={@flash} />

          {render_slot(@inner_block)}
        </main>
      </div>
    </div>
    """
  end
end
