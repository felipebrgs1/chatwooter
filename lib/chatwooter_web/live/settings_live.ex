defmodule ChatwooterWeb.SettingsLive do
  @moduledoc "Configurações da conta estilo Chatwoot: General, Inboxes, Agents."
  use ChatwooterWeb, :live_view

  alias Chatwooter.{Accounts, Inboxes}
  alias Chatwooter.Accounts.Account
  alias Chatwooter.Channels.Telegram.BotApi
  alias ChatwooterWeb.AppShell

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/app/settings/profile")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    account = Accounts.list_user_accounts(user) |> List.first()

    socket = assign(socket, :account, account)

    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(
        :email_form,
        to_form(Accounts.change_user_email(user, %{}, validate_unique: false))
      )
      |> assign(
        :password_form,
        to_form(Accounts.change_user_password(user, %{}, hash_password: false))
      )
      |> assign(:trigger_submit, false)

    if account do
      {:ok,
       socket
       |> assign(:inboxes, Inboxes.list_inboxes(account))
       |> assign(:members, Accounts.list_account_users(account))
       |> assign(:account_form, to_form(Account.changeset(account, %{}), as: "account"))
       |> assign(:inbox_form, to_form(%{"name" => "", "channel_type" => "whatsapp"}, as: "inbox"))
       |> assign(:invite_form, to_form(%{"email" => ""}, as: "invite"))
       |> assign(:editing_inbox_id, nil)
       |> assign(:editing_channel, nil)
       |> assign(:provider_token, nil)
       |> assign(:webhook_url, nil)
       |> assign(:editing_bot_username, nil)
       |> assign(:edit_form, nil)}
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
        {:noreply,
         assign(socket, :account_form, to_form(changeset, as: "account", action: :update))}
    end
  end

  def handle_event("create-inbox", %{"inbox" => params}, socket) do
    case Inboxes.create_inbox(socket.assigns.account, params) do
      {:ok, inbox} ->
        {:noreply,
         socket
         |> assign(:inboxes, Inboxes.list_inboxes(socket.assigns.account))
         |> assign(
           :inbox_form,
           to_form(%{"name" => "", "channel_type" => "whatsapp"}, as: "inbox")
         )
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

  def handle_event("edit-inbox", %{"id" => id}, socket) do
    inbox = Inboxes.get_inbox!(socket.assigns.account, id)

    {:noreply,
     socket
     |> assign(:editing_inbox_id, inbox.id)
     |> assign(:editing_channel, inbox.channel_type)
     |> assign(:provider_token, (inbox.provider_config || %{})["bot_token"])
     |> assign(:webhook_url, telegram_webhook_url(inbox))
     |> assign(:editing_bot_username, (inbox.provider_config || %{})["bot_username"])
     |> assign(:edit_form, to_form(Inboxes.change_inbox(inbox), as: "inbox"))}
  end

  def handle_event("validate-inbox", %{"inbox" => params}, socket) do
    inbox = Inboxes.get_inbox!(socket.assigns.account, socket.assigns.editing_inbox_id)

    {:noreply,
     socket
     |> assign(
       :provider_token,
       get_in(params, ["provider_config", "bot_token"]) || socket.assigns.provider_token
     )
     |> assign(
       :edit_form,
       to_form(Inboxes.change_inbox(inbox, params), as: "inbox", action: :validate)
     )}
  end

  def handle_event("save-inbox", %{"inbox" => params}, socket) do
    inbox = Inboxes.get_inbox!(socket.assigns.account, socket.assigns.editing_inbox_id)

    case Inboxes.update_inbox(inbox, params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:inboxes, Inboxes.list_inboxes(socket.assigns.account))
         |> assign(:editing_inbox_id, nil)
         |> assign(:editing_channel, nil)
         |> assign(:provider_token, nil)
         |> assign(:webhook_url, nil)
         |> assign(:editing_bot_username, nil)
         |> assign(:edit_form, nil)
         |> put_flash(:info, "Inbox updated.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :edit_form, to_form(changeset, as: "inbox", action: :update))}
    end
  end

  def handle_event("cancel-edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_inbox_id, nil)
     |> assign(:editing_channel, nil)
     |> assign(:provider_token, nil)
     |> assign(:webhook_url, nil)
     |> assign(:editing_bot_username, nil)
     |> assign(:edit_form, nil)}
  end

  def handle_event("test-telegram", _params, socket) do
    inbox = Inboxes.get_inbox!(socket.assigns.account, socket.assigns.editing_inbox_id)

    case (inbox.provider_config || %{})["bot_token"] do
      token when is_binary(token) and token != "" ->
        test_saved_token(socket, inbox)

      _ ->
        {:noreply, put_flash(socket, :error, "Save a bot token first.")}
    end
  end

  def handle_event("connect-telegram", _params, socket) do
    inbox = Inboxes.get_inbox!(socket.assigns.account, socket.assigns.editing_inbox_id)

    case (inbox.provider_config || %{})["bot_token"] do
      token when is_binary(token) and token != "" ->
        connect_saved_inbox(socket, inbox)

      _ ->
        {:noreply, put_flash(socket, :error, "Save a bot token first.")}
    end
  end

  def handle_event("invite", %{"invite" => %{"email" => email}}, socket) do
    case Accounts.invite_member(socket.assigns.account, String.trim(email)) do
      {:ok, user} ->
        Accounts.deliver_login_instructions(user, &url(~p"/app/login/#{&1}"))

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

  ## My profile (email + password — sudo enforced per action)

  def handle_event("validate-profile-email", %{"user" => params}, socket) do
    form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: form)}
  end

  def handle_event("save-profile-email", %{"user" => params}, socket) do
    user = socket.assigns.current_scope.user

    if Accounts.sudo_mode?(user, -10) do
      case Accounts.change_user_email(user, params) do
        %{valid?: true} = changeset ->
          Accounts.deliver_user_update_email_instructions(
            Ecto.Changeset.apply_action!(changeset, :insert),
            user.email,
            &url(~p"/app/settings/profile/confirm-email/#{&1}")
          )

          {:noreply,
           socket |> put_flash(:info, "A link to confirm your email change has been sent.")}

        changeset ->
          {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
      end
    else
      {:noreply, require_sudo(socket)}
    end
  end

  def handle_event("validate-profile-password", %{"user" => params}, socket) do
    form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: form)}
  end

  def handle_event("save-profile-password", %{"user" => params}, socket) do
    user = socket.assigns.current_scope.user

    if Accounts.sudo_mode?(user, -10) do
      case Accounts.change_user_password(user, params) do
        %{valid?: true} = changeset ->
          {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

        changeset ->
          {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
      end
    else
      {:noreply, require_sudo(socket)}
    end
  end

  defp require_sudo(socket) do
    socket
    |> put_flash(:error, "You must re-authenticate to access this page.")
    |> push_navigate(to: ~p"/app/login")
  end

  defp test_saved_token(socket, inbox) do
    case BotApi.get_me(inbox) do
      {:ok, %{username: username}} when is_binary(username) ->
        {:ok, _} = Inboxes.update_inbox(inbox, %{provider_config: %{"bot_username" => username}})

        {:noreply,
         socket
         |> assign(:inboxes, Inboxes.list_inboxes(socket.assigns.account))
         |> assign(:editing_bot_username, username)
         |> put_flash(:info, "Connected as @#{username}.")}

      {:ok, _} ->
        {:noreply, put_flash(socket, :error, "Telegram answered without a username.")}

      {:error, %{description: description}} when is_binary(description) ->
        {:noreply, put_flash(socket, :error, "Telegram error: #{description}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Telegram did not accept the token.")}
    end
  end

  defp connect_saved_inbox(socket, inbox) do
    with {:ok, inbox} <- Inboxes.ensure_webhook_secret(inbox),
         url = telegram_webhook_url(inbox),
         secret = (inbox.provider_config || %{})["webhook_secret"],
         {:ok, _} <- BotApi.set_webhook(inbox, url, secret),
         {:ok, _} <- Inboxes.update_inbox(inbox, %{provider_config: %{"webhook_url" => url}}) do
      {:noreply,
       socket
       |> assign(:inboxes, Inboxes.list_inboxes(socket.assigns.account))
       |> put_flash(:info, "Telegram webhook connected.")}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :edit_form, to_form(changeset, as: "inbox", action: :update))}

      {:error, %{description: description}} when is_binary(description) ->
        {:noreply, put_flash(socket, :error, "Telegram error: #{description}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not connect the webhook.")}
    end
  end

  defp telegram_webhook_url(inbox) do
    base = Application.get_env(:chatwooter, :webhook_base_url) || ChatwooterWeb.Endpoint.url()
    "#{base}/webhooks/telegram/#{inbox.id}"
  end

  defp channel_badge(:whatsapp), do: {"WhatsApp", "bg-emerald-100 text-emerald-700"}
  defp channel_badge(:telegram), do: {"Telegram", "bg-sky-100 text-sky-700"}

  defp configured?(%{channel_type: :telegram, provider_config: %{"bot_token" => t}})
       when is_binary(t) and t != "",
       do: true

  defp configured?(%{
         channel_type: :whatsapp,
         provider_config: %{"phone_number_id" => p, "access_token" => t}
       })
       when is_binary(p) and p != "" and is_binary(t) and t != "",
       do: true

  defp configured?(_inbox), do: false

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
              @live_action == action && "bg-highlight font-semibold text-slate-900",
              @live_action != action && "text-slate-600 hover:bg-slate-100"
            ]}
          >
            {label}
          </.link>
        </nav>

        <main class="min-w-0 flex-1 overflow-y-auto p-8">
          <Layouts.flash_group flash={@flash} />

          <div :if={@live_action == :general} class="max-w-xl">
            <h2 class="text-lg font-bold text-slate-900">General</h2>
            <p class="mb-6 text-sm text-slate-500">Account name and preferences.</p>
            <div class="rounded-xl border border-line bg-surface p-6">
              <.form
                :let={f}
                for={@account_form}
                id="account-form"
                phx-submit="save-account"
                class="space-y-4"
              >
                <.input field={f[:name]} type="text" label="Account name" required />
                <.input
                  field={f[:locale]}
                  type="select"
                  label="Language"
                  options={["Português (BR)": "pt-BR", English: "en"]}
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
              <.form
                :let={f}
                for={@inbox_form}
                id="inbox-form"
                phx-submit="create-inbox"
                class="flex items-end gap-3"
              >
                <div class="flex-1">
                  <.input field={f[:name]} type="text" label="Name" placeholder="Sales" required />
                </div>
                <div class="w-40">
                  <.input
                    field={f[:channel_type]}
                    type="select"
                    label="Channel"
                    options={[WhatsApp: "whatsapp", Telegram: "telegram"]}
                  />
                </div>
                <.button variant="primary">Create</.button>
              </.form>
            </div>

            <div class="overflow-hidden rounded-xl border border-line bg-surface">
              <div :if={@inboxes == []} class="p-8 text-center text-sm text-slate-500">
                No inboxes yet. Create one above to start receiving messages.
              </div>
              <div :for={inbox <- @inboxes} class="border-b border-line px-5 py-3 last:border-0">
                <div :if={@editing_inbox_id == inbox.id}>
                  <.form
                    :let={f}
                    for={@edit_form}
                    id="inbox-edit-form"
                    phx-change="validate-inbox"
                    phx-submit="save-inbox"
                    class="space-y-3"
                  >
                    <.input field={f[:name]} type="text" label="Name" required />
                    <.input
                      field={f[:greeting_message]}
                      type="textarea"
                      rows="2"
                      label="Greeting message"
                      placeholder="Olá! Como posso ajudar?"
                    />
                    <div :if={@editing_channel == :telegram} class="fieldset mb-2">
                      <label for="inbox_bot_token">
                        <span class="label mb-1">Bot token</span>
                        <input
                          type="password"
                          name="inbox[provider_config][bot_token]"
                          id="inbox_bot_token"
                          value={@provider_token}
                          placeholder="123456:ABC-DEF..."
                          autocomplete="off"
                          class={[
                            "w-full input",
                            @edit_form[:provider_config].errors != [] && "input-error"
                          ]}
                        />
                      </label>
                      <p
                        :for={{msg, _} <- @edit_form[:provider_config].errors}
                        class="mt-1 text-xs text-error"
                      >
                        {msg}
                      </p>
                    </div>
                    <div
                      :if={@editing_channel == :telegram}
                      class="space-y-2 rounded-lg border border-line bg-canvas p-4"
                    >
                      <div>
                        <p class="text-xs font-semibold text-slate-700">Webhook URL</p>
                        <code class="mt-1 block truncate rounded bg-ink px-2 py-1 text-[11px] text-white">
                          {@webhook_url}
                        </code>
                      </div>
                      <p :if={@editing_bot_username} class="text-xs text-slate-600">
                        Connected as <span class="font-semibold">@{@editing_bot_username}</span>
                      </p>
                      <div class="flex gap-2">
                        <button
                          type="button"
                          phx-click="test-telegram"
                          class="cursor-pointer rounded-lg border border-line bg-surface px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-100"
                        >
                          Test connection
                        </button>
                        <button
                          type="button"
                          phx-click="connect-telegram"
                          class="cursor-pointer rounded-lg border border-line bg-surface px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-100"
                        >
                          Connect webhook
                        </button>
                      </div>
                    </div>
                    <div class="flex gap-2">
                      <.button variant="primary">Save</.button>
                      <button
                        type="button"
                        phx-click="cancel-edit"
                        class="cursor-pointer rounded-lg px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-100"
                      >
                        Cancel
                      </button>
                    </div>
                  </.form>
                </div>
                <div :if={@editing_inbox_id != inbox.id} class="flex items-center justify-between">
                  <div>
                    <p class="text-sm font-semibold text-slate-900">{inbox.name}</p>
                    <p
                      :if={inbox.greeting_message}
                      class="mt-0.5 max-w-md truncate text-xs text-slate-500"
                    >
                      {inbox.greeting_message}
                    </p>
                    <% {label, pill} = channel_badge(inbox.channel_type) %>
                    <span class={"mt-1 inline-block rounded-full px-2 py-0.5 text-[10px] font-semibold #{pill}"}>
                      {label}
                    </span>
                    <span
                      :if={(inbox.provider_config || %{})["bot_username"]}
                      class="ml-1 mt-1 inline-block rounded-full bg-sky-100 px-2 py-0.5 text-[10px] font-semibold text-sky-700"
                    >
                      @{(inbox.provider_config || %{})["bot_username"]}
                    </span>
                    <span class={
                      if(configured?(inbox),
                        do:
                          "ml-1 mt-1 inline-block rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-semibold text-emerald-700",
                        else:
                          "ml-1 mt-1 inline-block rounded-full bg-slate-100 px-2 py-0.5 text-[10px] font-semibold text-slate-500"
                      )
                    }>
                      {if configured?(inbox), do: "Configured", else: "Not configured"}
                    </span>
                  </div>
                  <div class="flex shrink-0 items-center gap-1">
                    <button
                      phx-click="edit-inbox"
                      phx-value-id={inbox.id}
                      class="cursor-pointer rounded-lg px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-100"
                    >
                      Edit
                    </button>
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
            </div>
          </div>

          <div :if={@live_action == :agents} class="max-w-2xl">
            <h2 class="text-lg font-bold text-slate-900">Agents</h2>
            <p class="mb-6 text-sm text-slate-500">Who can access this account.</p>

            <div class="mb-6 rounded-xl border border-line bg-surface p-6">
              <h3 class="mb-4 text-sm font-semibold text-slate-900">Invite agent</h3>
              <.form
                :let={f}
                for={@invite_form}
                id="invite-form"
                phx-submit="invite"
                class="flex items-end gap-3"
              >
                <div class="flex-1">
                  <.input
                    field={f[:email]}
                    type="email"
                    label="Email"
                    placeholder="agent@acme.inc"
                    required
                  />
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
                      <span
                        :if={m.user_id == @current_scope.user.id}
                        class="ml-1 rounded bg-highlight px-1.5 text-[10px]"
                      >you</span>
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
          <div :if={@live_action == :profile} class="max-w-xl space-y-6">
            <div>
              <h2 class="text-lg font-bold text-slate-900">Profile</h2>
              <p class="mb-6 text-sm text-slate-500">Your email address and password.</p>
            </div>

            <div class="rounded-xl border border-line bg-surface p-6">
              <h3 class="mb-4 text-sm font-semibold text-slate-900">Email</h3>
              <.form
                :let={f}
                for={@email_form}
                id="email_form"
                phx-submit="save-profile-email"
                phx-change="validate-profile-email"
                class="space-y-4"
              >
                <.input
                  field={f[:email]}
                  type="email"
                  label="Email"
                  autocomplete="username"
                  spellcheck="false"
                  required
                />
                <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
              </.form>
            </div>

            <div class="rounded-xl border border-line bg-surface p-6">
              <h3 class="mb-4 text-sm font-semibold text-slate-900">Password</h3>
              <.form
                :let={f}
                for={@password_form}
                id="password_form"
                action={~p"/app/update-password"}
                method="post"
                phx-change="validate-profile-password"
                phx-submit="save-profile-password"
                phx-trigger-action={@trigger_submit}
                class="space-y-4"
              >
                <input
                  name={f[:email].name}
                  type="hidden"
                  id="hidden_user_email"
                  spellcheck="false"
                  value={@current_email}
                />
                <.input
                  field={f[:password]}
                  type="password"
                  label="New password"
                  autocomplete="new-password"
                  spellcheck="false"
                  required
                />
                <.input
                  field={f[:password_confirmation]}
                  type="password"
                  label="Confirm new password"
                  autocomplete="new-password"
                  spellcheck="false"
                />
                <.button variant="primary" phx-disable-with="Saving...">Save Password</.button>
              </.form>
            </div>
          </div>
        </main>
      </div>
    </div>
    """
  end
end
