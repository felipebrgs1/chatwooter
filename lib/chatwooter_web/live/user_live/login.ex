defmodule ChatwooterWeb.UserLive.Login do
  use ChatwooterWeb, :live_view

  alias Chatwooter.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-white">
      <%!-- Left: brand panel (desktop only) --%>
      <div class="relative hidden w-[55%] overflow-hidden bg-[#1f2937] lg:block">
        <img
          src={~p"/images/login-side.jpg"}
          alt=""
          class="absolute inset-0 h-full w-full object-cover"
        />
        <div class="absolute inset-0 bg-gradient-to-t from-[#1f2937] via-[#1f2937]/55 to-[#1f2937]/10" />
        <div class="relative flex h-full flex-col justify-between p-12">
          <div class="flex items-center gap-3">
            <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-[#1f93ff] to-[#25d366]">
              <svg viewBox="0 0 24 24" class="h-6 w-6 text-white" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
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
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-[#7dd3fc]">
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
                <.icon name="hero-chat-bubble-left-right" class="size-5 shrink-0 text-[#25d366]" />
                WhatsApp Cloud API + Telegram Bot API
              </li>
              <li class="flex items-center gap-3">
                <.icon name="hero-bolt" class="size-5 shrink-0 text-[#229ed9]" />
                Real-time inbox with presence and typing
              </li>
              <li class="flex items-center gap-3">
                <.icon name="hero-shield-check" class="size-5 shrink-0 text-[#7dd3fc]" />
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
            <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-[#1f93ff] to-[#25d366]">
              <svg viewBox="0 0 24 24" class="h-6 w-6 text-white" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M21 12a8 8 0 0 1-8 8H4l2-3a8 8 0 1 1 15-5z" />
              </svg>
            </span>
            <span class="text-lg font-bold tracking-tight text-slate-900">Chatwooter</span>
          </div>

          <div>
            <h2 class="text-2xl font-bold tracking-tight text-slate-900">Log in</h2>
            <p class="mt-2 text-sm text-slate-600">
              <%= if @current_scope do %>
                You need to reauthenticate to perform sensitive actions on your account.
              <% else %>
                Don't have an account? <.link
                  navigate={~p"/users/register"}
                  class="font-semibold text-[#1f93ff] hover:underline"
                  phx-no-format
                >Sign up</.link> for an account now.
              <% end %>
            </p>
          </div>

          <Layouts.flash_group flash={@flash} />

          <div :if={local_mail_adapter?()} class="alert alert-info">
            <.icon name="hero-information-circle" class="size-6 shrink-0" />
            <div>
              <p>You are running the local mail adapter.</p>
              <p>
                To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
              </p>
            </div>
          </div>

          <.form
            :let={f}
            for={@form}
            id="login_form_magic"
            action={~p"/users/log-in"}
            phx-submit="submit_magic"
          >
            <.input
              readonly={!!@current_scope}
              field={f[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              spellcheck="false"
              required
              phx-mounted={JS.focus()}
            />
            <.button class="w-full bg-[#1f93ff] text-white hover:bg-[#1976cc]">
              Log in with email <span aria-hidden="true">→</span>
            </.button>
          </.form>

          <div class="divider">or</div>

          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
          >
            <.input
              readonly={!!@current_scope}
              field={f[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              spellcheck="false"
              required
            />
            <.input
              field={@form[:password]}
              type="password"
              label="Password"
              autocomplete="current-password"
              spellcheck="false"
            />
            <.button
              class="w-full bg-[#1f93ff] text-white hover:bg-[#1976cc]"
              name={@form[:remember_me].name}
              value="true"
            >
              Log in and stay logged in <span aria-hidden="true">→</span>
            </.button>
            <.button class="mt-2 w-full">
              Log in only this time
            </.button>
          </.form>
        </div>
      </main>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:chatwooter, Chatwooter.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
