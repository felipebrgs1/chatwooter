defmodule ChatwooterWeb.SettingsLive do
  @moduledoc "Configurações da conta estilo Chatwoot: General, Inboxes, Agents."
  use ChatwooterWeb, :live_view

  alias Chatwooter.{Accounts, Inboxes}
  alias Chatwooter.Accounts.Account
  alias ChatwooterWeb.AppShell

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    account = Accounts.list_user_accounts(user) |> List.first()

    socket = assign(socket, :account, account)

    if account do
      {:ok,
       socket
       |> assign(:inboxes, Inboxes.list_inboxes(account))
       |> assign(:members, Accounts.list_account_users(account))
       |> assign(:account_form, to_form(Account.changeset(account, %{}), as: "account"))
       |> assign(:inbox_form, to_form(%{"name" => "", "channel_type" => "whatsapp"}, as: "inbox"))
       |> assign(:invite_form, to_form(%{"email" => ""}, as: "invite"))}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("save-account", %{"account" => params}, socket) do
    case Accounts.update_account(socket.assigns.account, params) do
      {:ok, account} ->
        {:noreply,
         socket
         |> assign(:account, account)
         |> assign(:account_form, to_form(Account.changeset(account, %{}), as: "account"))
         |> put_flash(:info, "Account updated.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :account_form, to_form(changeset, as: "account", action: :update))}
    end
  end

  def handle_event("create-inbox", %{"inbox" => params}, socket) do
    case Inboxes.create_inbox(socket.assigns.account, params) do
      {:ok, inbox} ->
        {:noreply,
         socket
         |> assign(:inboxes, Inboxes.list_inboxes(socket.assigns.account))
         |> assign(:inbox_form, to_form(%{"name" => "", "channel_type" => "whatsapp"}, as: "inbox"))
         |> put_flash(:info, "Inbox #{inbox.name} created.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :inbox_form, to_form(changeset, as: "inbox", action: :insert))}
    end
  end

  def handle_event("delete-inbox", %{"id" => id}, socket) do
    {:ok, _} = Inboxes.delete_inbox(socket.assigns.account, id)

    {:noreply,
     socket
     |> assign(:inboxes, Inboxes.list_inboxes(socket.assigns.account))
     |> put_flash(:info, "Inbox deleted.")}
  end

  def handle_event("invite", %{"invite" => %{"email" => email}}, socket) do
    case Accounts.invite_member(socket.assigns.account, String.trim(email)) do
      {:ok, user} ->
        Accounts.deliver_login_instructions(user, &url(~p"/users/log-in/#{&1}"))

        {:noreply,
         socket
         |> assign(:members, Accounts.list_account_users(socket.assigns.account))
         |> assign(:invite_form, to_form(%{"email" => ""}, as: "invite"))
         |> put_flash(:info, "Invitation sent to #{user.email}.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not invite (already a member?).")}
    end
  end

  def handle_event("change-role", %{"role" => role, "id" => user_id}, socket) do
    user = Accounts.get_user!(String.to_integer(user_id))

    case Accounts.update_member_role(socket.assigns.account, user, role) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:members, Accounts.list_account_users(socket.assigns.account))
         |> put_flash(:info, "Role updated.")}

      {:error, :last_admin} ->
        {:noreply, put_flash(socket, :error, "The account needs at least one admin.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update role.")}
    end
  end

  def handle_event("remove-member", %{"id" => user_id}, socket) do
    current_id = socket.assigns.current_scope.user.id

    if String.to_integer(user_id) == current_id do
      {:noreply, put_flash(socket, :error, "You cannot remove yourself.")}
    else
      user = Accounts.get_user!(String.to_integer(user_id))

      case Accounts.remove_member(socket.assigns.account, user) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:members, Accounts.list_account_users(socket.assigns.account))
           |> put_flash(:info, "Member removed.")}

        {:error, :last_admin} ->
          {:noreply, put_flash(socket, :error, "The account needs at least one admin.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not remove member.")}
      end
    end
  end

  defp channel_badge(:whatsapp), do: {"WhatsApp", "bg-emerald-100 text-emerald-700"}
  defp channel_badge(:telegram), do: {"Telegram", "bg-sky-100 text-sky-700"}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen overflow-hidden bg-canvas">
      <AppShell.sidebar
        current_scope={@current_scope}
        account_name={@account && @account.name}
        active={:settings}
      />

      <div class="flex min-w-0 flex-1">
        <nav class="w-56 shrink-0 space-y-1 border-r border-line bg-surface p-4">
          <p class="px-3 pb-2 text-xs font-semibold uppercase tracking-wider text-slate-400">Settings</p>
          <.link
            :for={{label, action, path} <- [{"General", :general, ~p"/app/settings"}, {"Inboxes", :inboxes, ~p"/app/settings/inboxes"}, {"Agents", :agents, ~p"/app/settings/agents"}]}
            navigate={path}
            class={[
              "block rounded-lg px-3 py-2 text-sm",
              @live_action == action && "bg-highlight font-semibold text-slate-900",
              @live_action != action && "text-slate-600 hover:bg-slate-100"
            ]}
          >
            {label}
          </.link>
          <div class="border-t border-line pt-2">
            <.link navigate={~p"/users/settings"} class="block rounded-lg px-3 py-2 text-sm text-slate-600 hover:bg-slate-100">
              My profile
            </.link>
          </div>
        </nav>

        <main class="min-w-0 flex-1 overflow-y-auto p-8">
          <Layouts.flash_group flash={@flash} />

          <div :if={@live_action == :general} class="max-w-xl">
            <h2 class="text-lg font-bold text-slate-900">General</h2>
            <p class="mb-6 text-sm text-slate-500">Account name and preferences.</p>
            <div class="rounded-xl border border-line bg-surface p-6">
              <.form :let={f} for={@account_form} id="account-form" phx-submit="save-account" class="space-y-4">
                <.input field={f[:name]} type="text" label="Account name" required />
                <.input
                  field={f[:locale]}
                  type="select"
                  label="Language"
                  options={["Português (BR)": "pt-BR", "English": "en"]}
                />
                <.button variant="primary">Save changes</.button>
              </.form>
            </div>
          </div>

          <div :if={@live_action == :inboxes} class="max-w-2xl">
            <h2 class="text-lg font-bold text-slate-900">Inboxes</h2>
            <p class="mb-6 text-sm text-slate-500">WhatsApp and Telegram entry points.</p>

            <div class="mb-6 rounded-xl border border-line bg-surface p-6">
              <h3 class="mb-4 text-sm font-semibold text-slate-900">New inbox</h3>
              <.form :let={f} for={@inbox_form} id="inbox-form" phx-submit="create-inbox" class="flex items-end gap-3">
                <div class="flex-1">
                  <.input field={f[:name]} type="text" label="Name" placeholder="Sales" required />
                </div>
                <div class="w-40">
                  <.input
                    field={f[:channel_type]}
                    type="select"
                    label="Channel"
                    options={["WhatsApp": "whatsapp", "Telegram": "telegram"]}
                  />
                </div>
                <.button variant="primary">Create</.button>
              </.form>
            </div>

            <div class="overflow-hidden rounded-xl border border-line bg-surface">
              <div :if={@inboxes == []} class="p-8 text-center text-sm text-slate-500">
                No inboxes yet. Create one above to start receiving messages.
              </div>
              <div :for={inbox <- @inboxes} class="flex items-center justify-between border-b border-line px-5 py-3 last:border-0">
                <div>
                  <p class="text-sm font-semibold text-slate-900">{inbox.name}</p>
                  <% {label, pill} = channel_badge(inbox.channel_type) %>
                  <span class={"mt-1 inline-block rounded-full px-2 py-0.5 text-[10px] font-semibold #{pill}"}>
                    {label}
                  </span>
                </div>
                <button
                  phx-click="delete-inbox"
                  phx-value-id={inbox.id}
                  data-confirm="Delete this inbox and all its conversations?"
                  class="cursor-pointer rounded-lg px-3 py-1.5 text-xs font-semibold text-danger hover:bg-danger hover:text-white"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>

          <div :if={@live_action == :agents} class="max-w-2xl">
            <h2 class="text-lg font-bold text-slate-900">Agents</h2>
            <p class="mb-6 text-sm text-slate-500">Who can access this account.</p>

            <div class="mb-6 rounded-xl border border-line bg-surface p-6">
              <h3 class="mb-4 text-sm font-semibold text-slate-900">Invite agent</h3>
              <.form :let={f} for={@invite_form} id="invite-form" phx-submit="invite" class="flex items-end gap-3">
                <div class="flex-1">
                  <.input field={f[:email]} type="email" label="Email" placeholder="agent@acme.inc" required />
                </div>
                <.button variant="primary">Send invite</.button>
              </.form>
            </div>

            <div class="overflow-hidden rounded-xl border border-line bg-surface">
              <div
                :for={m <- @members}
                id={"member-#{m.user_id}"}
                class="flex items-center justify-between gap-3 border-b border-line px-5 py-3 last:border-0"
              >
                <div class="flex min-w-0 items-center gap-3">
                  <span class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand text-xs font-bold text-white">
                    {AppShell.initials(m.user.email)}
                  </span>
                  <div class="min-w-0">
                    <p class="truncate text-sm font-semibold text-slate-900">
                      {m.user.email}
                      <span :if={m.user_id == @current_scope.user.id} class="ml-1 rounded bg-highlight px-1.5 text-[10px]">you</span>
                    </p>
                  </div>
                </div>
                <div class="flex shrink-0 items-center gap-2">
                  <select
                    name="role"
                    phx-change="change-role"
                    phx-value-id={m.user_id}
                    class="rounded-lg border border-line bg-surface px-2 py-1.5 text-xs font-semibold"
                  >
                    <option value="admin" selected={m.role == :admin}>Admin</option>
                    <option value="agent" selected={m.role == :agent}>Agent</option>
                  </select>
                  <button
                    :if={m.user_id != @current_scope.user.id}
                    phx-click="remove-member"
                    phx-value-id={m.user_id}
                    data-confirm="Remove this member?"
                    class="cursor-pointer rounded-lg px-2 py-1.5 text-xs font-semibold text-danger hover:bg-danger hover:text-white"
                  >
                    Remove
                  </button>
                </div>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
    """
  end

end
