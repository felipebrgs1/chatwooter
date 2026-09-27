defmodule ChatwooterWeb.UserLive.Login do
  use ChatwooterWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-surface">
      <%!-- Left: brand panel (desktop only) --%>
      <div class="relative hidden w-[55%] overflow-hidden bg-ink lg:block">
        <img
          src={~p"/images/login-side.jpg"}
          alt=""
          class="absolute inset-0 h-full w-full object-cover"
        />
        <div class="absolute inset-0 bg-gradient-to-t from-ink via-ink/55 to-ink/10" />
        <div class="relative flex h-full flex-col justify-between p-12">
          <div class="flex items-center gap-3">
            <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-brand to-wa">
              <svg
                viewBox="0 0 24 24"
                class="h-6 w-6 text-white"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M21 12a8 8 0 0 1-8 8H4l2-3a8 8 0 1 1 15-5z" />
                <circle cx="9" cy="12" r="0.5" fill="currentColor" />
                <circle cx="13" cy="12" r="0.5" fill="currentColor" />
                <circle cx="17" cy="12" r="0.5" fill="currentColor" />
              </svg>
            </span>
            <span class="text-lg font-bold tracking-tight text-white">Chatwooter</span>
          </div>
          <div class="space-y-6">
            <div class="space-y-3">
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-sky-300">
                Customer messaging, simplified
              </p>
              <h1 class="max-w-md text-4xl font-bold leading-tight tracking-tight text-white">
                Every conversation, one inbox.
              </h1>
              <p class="max-w-md text-base text-slate-300">
                Answer WhatsApp and Telegram from a single real-time dashboard.
              </p>
            </div>
            <ul class="space-y-3 text-sm text-slate-200">
              <li class="flex items-center gap-3">
                <.icon name="hero-chat-bubble-left-right" class="size-5 shrink-0 text-wa" />
                WhatsApp Cloud API + Telegram Bot API
              </li>
              <li class="flex items-center gap-3">
                <.icon name="hero-bolt" class="size-5 shrink-0 text-tg" />
                Real-time inbox with presence and typing
              </li>
              <li class="flex items-center gap-3">
                <.icon name="hero-shield-check" class="size-5 shrink-0 text-sky-300" />
                Teams, labels and private notes
              </li>
            </ul>
          </div>
        </div>
      </div>

      <%!-- Right: login form --%>
      <main class="flex flex-1 items-center justify-center px-6 py-12 sm:px-12">
        <div class="w-full max-w-sm space-y-6">
          <div class="flex items-center gap-3 lg:hidden">
            <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-brand to-wa">
              <svg
                viewBox="0 0 24 24"
                class="h-6 w-6 text-white"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M21 12a8 8 0 0 1-8 8H4l2-3a8 8 0 1 1 15-5z" />
              </svg>
            </span>
            <span class="text-lg font-bold tracking-tight text-slate-900">Chatwooter</span>
          </div>

          <div>
            <h2 class="text-2xl font-bold tracking-tight text-slate-900">Log in</h2>
            <p :if={@current_scope} class="mt-2 text-sm text-slate-600">
              You need to reauthenticate to perform sensitive actions on your account.
            </p>
          </div>

          <Layouts.flash_group flash={@flash} />

          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/app/login"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
          >
            <.input
              field={f[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              spellcheck="false"
              required
              phx-mounted={JS.focus()}
            />
            <.input
              field={@form[:password]}
              type="password"
              label="Password"
              autocomplete="current-password"
              spellcheck="false"
              required
            />
            <.input
              field={f[:remember_me]}
              type="checkbox"
              label="Keep me logged in on this device"
            />
            <.button variant="primary" class="w-full">
              Log in <span aria-hidden="true">→</span>
            </.button>
          </.form>
        </div>
      </main>
    </div>
    """
  end

  @impl true
  # Logged-in users go straight to the dashboard — except the sudo
  # re-auth flow, which arrives carrying this exact error flash
  # (see UserAuth.on_mount(:require_sudo_mode, ...)).
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}, flash: flash}} = socket)
      when not is_nil(user) do
    if Phoenix.Flash.get(flash, :error) == "You must re-authenticate to access this page." do
      {:ok, mount_form(socket)}
    else
      {:ok, push_navigate(socket, to: ~p"/app")}
    end
  end

  def mount(_params, _session, socket) do
    {:ok, mount_form(socket)}
  end

  defp mount_form(socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email, "remember_me" => "true"}, as: "user")

    assign(socket, form: form, trigger_submit: false)
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
