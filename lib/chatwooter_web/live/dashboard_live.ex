defmodule ChatwooterWeb.DashboardLive do
  @moduledoc "Inbox unificada estilo Chatwoot: sidebar + lista + thread + painel do contato."
  use ChatwooterWeb, :live_view

  alias Chatwooter.{Accounts, Conversations, Inboxes}
  alias ChatwooterWeb.AppShell

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    account = Accounts.list_user_accounts(user) |> List.first()

    socket =
      socket
      |> assign(:account, account)
      |> assign(:inboxes, [])
      |> assign(:conversations, [])
      |> assign(:filter_status, "all")
      |> assign(:search, "")
      |> assign(:selected, nil)
      |> assign(:conv_topic, nil)
      |> assign(:messages, [])
      |> assign(:message_form, to_form(%{"content" => ""}, as: "message"))

    if account do
      Phoenix.PubSub.subscribe(Chatwooter.PubSub, "account:#{account.id}")

      {:ok, socket |> assign(:inboxes, Inboxes.list_inboxes(account)) |> load_conversations()}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"conversation_id" => id}, _uri, %{assigns: %{account: account}} = socket)
      when not is_nil(account) do
    conv = Conversations.get_conversation!(account, id)

    if socket.assigns.conv_topic,
      do: Phoenix.PubSub.unsubscribe(Chatwooter.PubSub, socket.assigns.conv_topic)

    topic = "conversation:#{conv.id}"
    Phoenix.PubSub.subscribe(Chatwooter.PubSub, topic)

    {:noreply,
     socket
     |> assign(:selected, conv)
     |> assign(:conv_topic, topic)
     |> assign(:messages, conv.messages)
     |> assign(:message_form, to_form(%{"content" => ""}, as: "message"))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket |> assign(:selected, nil) |> assign(:messages, [])}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:search, q) |> load_conversations()}
  end

  def handle_event("noop", _params, socket), do: {:noreply, socket}

  def handle_event("send", %{"message" => %{"content" => content}}, socket) do
    content = String.trim(content)

    if content == "" do
      {:noreply, socket}
    else
      {:ok, _} =
        Conversations.add_message(socket.assigns.selected, %{
          content: content,
          message_type: "outgoing",
          sender_id: socket.assigns.current_scope.user.id
        })

      {:noreply, assign(socket, :message_form, to_form(%{"content" => ""}, as: "message"))}
    end
  end

  def handle_event("set-status", %{"status" => status}, socket) do
    {:ok, conv} = Conversations.set_status(socket.assigns.selected, status)

    {:noreply,
     socket
     |> assign(:selected, Conversations.get_conversation!(socket.assigns.account, conv.id))
     |> assign(:messages, Conversations.get_conversation!(socket.assigns.account, conv.id).messages)
     |> load_conversations()}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    socket =
      if socket.assigns.selected && message.conversation_id == socket.assigns.selected.id do
        update(socket, :messages, &(&1 ++ [message]))
      else
        socket
      end

    {:noreply, load_conversations(socket)}
  end

  def handle_info({:conversation_updated, _id}, socket) do
    socket =
      if socket.assigns.selected do
        conv = Conversations.get_conversation!(socket.assigns.account, socket.assigns.selected.id)
        socket |> assign(:selected, conv) |> assign(:messages, conv.messages)
      else
        socket
      end

    {:noreply, load_conversations(socket)}
  end

  defp load_conversations(%{assigns: %{account: nil}} = socket),
    do: assign(socket, :conversations, [])

  defp load_conversations(socket) do
    assign(socket, :conversations,
      Conversations.list_conversations(socket.assigns.account,
        status: socket.assigns.filter_status,
        search: socket.assigns.search
      )
    )
  end

  defp status_badge(:open), do: {"Open", "bg-emerald-100 text-emerald-700"}
  defp status_badge(:pending), do: {"Pending", "bg-amber-100 text-amber-700"}
  defp status_badge(:resolved), do: {"Resolved", "bg-slate-200 text-slate-600"}

  defp contact_of(conv), do: conv.contact_inbox.contact

  defp last_message(conv), do: List.last(conv.messages || [])

  defp last_message_text(conv) do
    case last_message(conv) do
      nil -> "—"
      msg -> msg.content
    end
  end

  defp last_message_at(conv) do
    case last_message(conv) do
      nil -> ""
      msg -> Calendar.strftime(msg.inserted_at, "%H:%M")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen overflow-hidden bg-canvas">
      <AppShell.sidebar
        current_scope={@current_scope}
        account_name={@account && @account.name}
        active={:conversations}
      />


      <section class="flex w-80 shrink-0 flex-col border-r border-slate-200 bg-surface">
        <div class="space-y-3 border-b border-slate-200 p-4">
          <div class="flex items-center justify-between">
            <h2 class="text-sm font-bold text-slate-900">Conversations</h2>
            <span class="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-semibold text-slate-600">
              {length(@conversations)}
            </span>
          </div>
          <form id="conversation-search" phx-change="search" phx-submit="noop" phx-debounce="300">
            <input
              type="text"
              name="q"
              value={@search}
              placeholder="Search conversations…"
              autocomplete="off"
              class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand focus:outline-none"
            />
          </form>
          <div class="flex gap-1 text-xs font-semibold">
            <.link
              :for={s <- ["all", "open", "resolved"]}
              patch={~p"/app?status=#{s}"}
              class={[
                "rounded-lg px-3 py-1.5 capitalize",
                (@filter_status == s && "bg-brand text-white") || "text-slate-600 hover:bg-slate-100"
              ]}
            >
              {s}
            </.link>
          </div>
        </div>

        <div class="flex-1 overflow-y-auto">
          <div :if={@conversations == []} class="p-8 text-center text-sm text-slate-500">
            <p class="font-semibold text-slate-700">No conversations yet</p>
            <p class="mt-1">New WhatsApp and Telegram messages will show up here.</p>
          </div>
          <.link
            :for={conv <- @conversations}
            patch={~p"/app?conversation_id=#{conv.id}"}
            id={"conv-#{conv.id}"}
            class={[
              "block border-b border-slate-100 px-4 py-3 hover:bg-slate-50",
              @selected && @selected.id == conv.id && "bg-highlight"
            ]}
          >
            <div class="flex items-center gap-3">
              <span class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-brand to-wa text-xs font-bold text-white">
                {AppShell.initials(contact_of(conv).name)}
              </span>
              <div class="min-w-0 flex-1">
                <div class="flex items-center justify-between gap-2">
                  <p class="truncate text-sm font-semibold text-slate-900">{contact_of(conv).name}</p>
                  <span class="shrink-0 text-[11px] text-slate-400">{last_message_at(conv)}</span>
                </div>
                <div class="flex items-center justify-between gap-2">
                  <p class="truncate text-xs text-slate-500">{last_message_text(conv)}</p>
                  <% {label, pill} = status_badge(conv.status) %>
                  <span class={"shrink-0 rounded-full px-2 py-0.5 text-[10px] font-semibold #{pill}"}>
                    {label}
                  </span>
                </div>
              </div>
            </div>
          </.link>
        </div>
      </section>

      <main class="flex min-w-0 flex-1 flex-col">
        <div :if={!@selected} class="flex flex-1 items-center justify-center">
          <div class="text-center">
            <p class="text-sm font-semibold text-slate-700">Select a conversation</p>
            <p class="mt-1 text-xs text-slate-500">Choose one from the list to start replying.</p>
          </div>
        </div>

        <div :if={@selected} class="flex min-h-0 flex-1 flex-col">
          <div class="flex items-center justify-between border-b border-slate-200 bg-surface px-6 py-3">
            <div class="flex items-center gap-3">
              <span class="flex h-10 w-10 items-center justify-center rounded-full bg-gradient-to-br from-brand to-wa text-sm font-bold text-white">
                {AppShell.initials(contact_of(@selected).name)}
              </span>
              <div>
                <p class="text-sm font-bold text-slate-900">{contact_of(@selected).name}</p>
                <p class="text-xs text-slate-500">
                  {contact_of(@selected).phone_number} · via {@selected.contact_inbox.inbox.name}
                </p>
              </div>
            </div>
            <div class="flex gap-1 text-xs font-semibold">
              <button
                :for={s <- ["open", "pending", "resolved"]}
                phx-click="set-status"
                phx-value-status={s}
                class={[
                  "cursor-pointer rounded-lg px-3 py-1.5 capitalize",
                  (@selected.status == String.to_atom(s) && "bg-ink text-white") ||
                    "text-slate-600 hover:bg-slate-100"
                ]}
              >
                {s}
              </button>
            </div>
          </div>

          <div id="thread" class="flex-1 space-y-3 overflow-y-auto px-6 py-4">
            <div :for={msg <- @messages} class={["flex", msg.message_type == :outgoing && "justify-end"]}>
              <div class={["max-w-xl", msg.message_type == :outgoing && "bubble-agent", msg.message_type != :outgoing && "bubble-contact"]}>
                <p class="text-sm text-slate-800">{msg.content}</p>
                <p class="mt-1 text-right text-[10px] text-slate-400">
                  {Calendar.strftime(msg.inserted_at, "%d/%m %H:%M")}
                </p>
              </div>
            </div>
          </div>

          <.form :let={f} for={@message_form} id="composer" phx-submit="send" class="border-t border-slate-200 bg-surface p-4">
            <div class="flex items-end gap-2">
              <div class="flex-1">
                <.input
                  field={f[:content]}
                  type="textarea"
                  rows="2"
                  placeholder="Type a reply… (Enter to send)"
                  autocomplete="off"
                />
              </div>
              <.button variant="primary">
                Send <.icon name="hero-paper-airplane" class="size-4" />
              </.button>
            </div>
          </.form>
        </div>
      </main>

      <aside class="hidden w-72 shrink-0 flex-col border-l border-slate-200 bg-surface p-5 xl:flex">
        <div :if={@selected}>
          <div class="flex flex-col items-center text-center">
            <span class="flex h-16 w-16 items-center justify-center rounded-full bg-gradient-to-br from-brand to-wa text-xl font-bold text-white">
              {AppShell.initials(contact_of(@selected).name)}
            </span>
            <p class="mt-3 text-sm font-bold text-slate-900">{contact_of(@selected).name}</p>
            <p class="text-xs text-slate-500">{contact_of(@selected).phone_number}</p>
          </div>
          <dl class="mt-6 space-y-3 text-xs">
            <div class="flex justify-between border-b border-slate-100 pb-2">
              <dt class="text-slate-500">Channel</dt>
              <dd class="font-semibold text-slate-800">{@selected.contact_inbox.inbox.name}</dd>
            </div>
            <div class="flex justify-between border-b border-slate-100 pb-2">
              <dt class="text-slate-500">Status</dt>
              <% {label, _} = status_badge(@selected.status) %>
              <dd class="font-semibold capitalize text-slate-800">{label}</dd>
            </div>
            <div class="flex justify-between border-b border-slate-100 pb-2">
              <dt class="text-slate-500">Messages</dt>
              <dd class="font-semibold text-slate-800">{length(@messages)}</dd>
            </div>
            <div class="flex justify-between">
              <dt class="text-slate-500">Opened</dt>
              <dd class="font-semibold text-slate-800">
                {Calendar.strftime(@selected.inserted_at, "%d/%m/%Y")}
              </dd>
            </div>
          </dl>
        </div>
        <div :if={!@selected} class="text-center text-xs text-slate-500">
          Contact details will appear here.
        </div>
      </aside>
    </div>
    """
  end
end
