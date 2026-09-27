defmodule ChatwooterWeb.AppShell do
  @moduledoc "Chrome compartilhado do app (sidebar usada no dashboard e settings)."
  use ChatwooterWeb, :html

  attr :current_scope, :map, required: true
  attr :account_name, :string, default: nil
  attr :inboxes, :list, default: []
  attr :filter_inbox, :string, default: nil

  attr :active, :atom,
    default: :conversations,
    values: [:conversations, :contacts, :companies, :settings]

  def sidebar(assigns) do
    ~H"""
    <aside
      id="app-sidebar"
      class="hidden w-56 shrink-0 flex-col border-r border-line bg-surface text-ink md:flex"
    >
      <div class="flex items-center gap-3 border-b border-line px-4 py-4">
        <span class="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-brand to-wa">
          <svg
            viewBox="0 0 24 24"
            class="h-5 w-5 text-white"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M21 12a8 8 0 0 1-8 8H4l2-3a8 8 0 1 1 15-5z" />
          </svg>
        </span>
        <div class="min-w-0">
          <p class="truncate text-sm font-semibold">{@account_name || "Chatwooter"}</p>
          <p class="text-xs opacity-60">Workspace</p>
        </div>
      </div>

      <nav class="flex-1 space-y-1 overflow-y-auto px-2 py-4">
        <.link
          navigate={~p"/app"}
          class={[
            "flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors",
            @active == :conversations && "bg-brand-soft font-semibold text-brand-deep",
            @active != :conversations && "hover:bg-highlight"
          ]}
        >
          <.icon name="hero-chat-bubble-left-right" class="size-5" /> Conversations
        </.link>
        <div :if={@active == :conversations} class="space-y-1 pb-3 pl-3 pt-2">
          <.link
            id="sidebar-all-conversations"
            patch={~p"/app"}
            class="block rounded-lg px-3 py-1.5 text-xs transition-colors hover:bg-highlight"
          >All conversations</.link>
          <p class="px-3 pt-3 text-[11px] font-semibold uppercase tracking-wider opacity-60">
            Channels
          </p>
          <.link
            :for={inbox <- @inboxes}
            id={"inbox-#{inbox.id}"}
            patch={~p"/app?inbox_id=#{inbox.id}"}
            aria-current={if(@filter_inbox == to_string(inbox.id), do: "page")}
            class={[
              "flex items-center gap-2 truncate rounded-lg px-3 py-2 text-xs transition-colors hover:bg-highlight",
              @filter_inbox == to_string(inbox.id) && "bg-brand-soft font-semibold text-brand-deep"
            ]}
          >
            <.icon
              name={
                if(inbox.channel_type == :telegram,
                  do: "hero-paper-airplane",
                  else: "hero-chat-bubble-left-right"
                )
              }
              class="size-4 shrink-0"
            />
            <span class="truncate">{inbox.name}</span>
          </.link>
        </div>
        <.link
          navigate={~p"/app/contacts"}
          class={[
            "flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors",
            @active == :contacts && "bg-brand-soft font-semibold text-brand-deep",
            @active != :contacts && "hover:bg-highlight"
          ]}
        >
          <.icon name="hero-users" class="size-5" /> Contacts
        </.link>
        <.link
          navigate={~p"/app/companies"}
          class={[
            "flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors",
            @active == :companies && "bg-brand-soft font-semibold text-brand-deep",
            @active != :companies && "hover:bg-highlight"
          ]}
        >
          <.icon name="hero-building-office" class="size-5" /> Companies
        </.link>
        <.link
          navigate={~p"/app/settings"}
          class={[
            "flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors",
            @active == :settings && "bg-brand-soft font-semibold text-brand-deep",
            @active != :settings && "hover:bg-highlight"
          ]}
        >
          <.icon name="hero-cog-6-tooth" class="size-5" /> Settings
        </.link>
      </nav>

      <div class="border-t border-line p-4">
        <div class="flex items-center gap-3">
          <span class="flex h-8 w-8 items-center justify-center rounded-full bg-brand text-xs font-bold text-white">
            {initials(display_name(@current_scope.user))}
          </span>
          <p class="truncate text-xs text-ink">
            {display_name(@current_scope.user)}
          </p>
        </div>
        <.link
          href={~p"/app/logout"}
          method="delete"
          class="mt-3 flex items-center gap-2 text-xs text-ink opacity-70 transition-opacity hover:opacity-100"
        >
          <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> Log out
        </.link>
      </div>
    </aside>
    """
  end

  defp display_name(%{name: name, email: email}) when name in [nil, ""], do: email
  defp display_name(%{name: name}), do: name

  def initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end
end
