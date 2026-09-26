defmodule ChatwooterWeb.AppShell do
  @moduledoc "Chrome compartilhado do app (sidebar usada no dashboard e settings)."
  use ChatwooterWeb, :html

  attr :current_scope, :map, required: true
  attr :account_name, :string, default: nil

  attr :active, :atom,
    default: :conversations,
    values: [:conversations, :contacts, :companies, :settings]

  def sidebar(assigns) do
    ~H"""
    <aside class="flex w-60 shrink-0 flex-col bg-ink text-slate-300">
      <div class="flex items-center gap-3 px-5 pb-6 pt-6">
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
        <div>
          <p class="text-sm font-bold tracking-tight text-white">Chatwooter</p>
          <p class="truncate text-xs text-slate-400">{@account_name}</p>
        </div>
      </div>

      <nav class="flex-1 space-y-1 px-3">
        <.link
          navigate={~p"/app"}
          class={[
            "flex items-center gap-3 rounded-lg px-3 py-2 text-sm",
            @active == :conversations && "bg-white/10 font-semibold text-white",
            @active != :conversations && "hover:bg-white/5 hover:text-white"
          ]}
        >
          <.icon name="hero-chat-bubble-left-right" class="size-5" /> Conversations
        </.link>
        <.link
          navigate={~p"/app/contacts"}
          class={[
            "flex items-center gap-3 rounded-lg px-3 py-2 text-sm",
            @active == :contacts && "bg-white/10 font-semibold text-white",
            @active != :contacts && "hover:bg-white/5 hover:text-white"
          ]}
        >
          <.icon name="hero-users" class="size-5" /> Contacts
        </.link>
        <.link
          navigate={~p"/app/companies"}
          class={[
            "flex items-center gap-3 rounded-lg px-3 py-2 text-sm",
            @active == :companies && "bg-white/10 font-semibold text-white",
            @active != :companies && "hover:bg-white/5 hover:text-white"
          ]}
        >
          <.icon name="hero-building-office" class="size-5" /> Companies
        </.link>
        <.link
          navigate={~p"/app/settings"}
          class={[
            "flex items-center gap-3 rounded-lg px-3 py-2 text-sm",
            @active == :settings && "bg-white/10 font-semibold text-white",
            @active != :settings && "hover:bg-white/5 hover:text-white"
          ]}
        >
          <.icon name="hero-cog-6-tooth" class="size-5" /> Settings
        </.link>
      </nav>

      <div class="border-t border-white/10 p-4">
        <div class="flex items-center gap-3">
          <span class="flex h-8 w-8 items-center justify-center rounded-full bg-brand text-xs font-bold text-white">
            {initials(@current_scope.user.name || @current_scope.user.email)}
          </span>
          <p class="truncate text-xs text-slate-300">
            {@current_scope.user.name || @current_scope.user.email}
          </p>
        </div>
        <.link
          href={~p"/app/logout"}
          method="delete"
          class="mt-3 flex items-center gap-2 text-xs text-slate-400 hover:text-white"
        >
          <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> Log out
        </.link>
      </div>
    </aside>
    """
  end

  def initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end
end
