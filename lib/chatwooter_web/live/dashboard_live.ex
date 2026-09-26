defmodule ChatwooterWeb.DashboardLive do
  @moduledoc "Inbox unificada estilo Chatwoot: sidebar + lista + thread + painel do contato."
  use ChatwooterWeb, :live_view

  alias Chatwooter.{Accounts, Conversations, Inboxes}
  alias Chatwooter.Workers.TelegramSender
  alias ChatwooterWeb.AppShell

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    account = Accounts.list_user_accounts(user) |> List.first()

    socket =
      socket
      |> assign(:account, account)
      |> assign(:inboxes, [])
      |> assign(:conversation_count, 0)
      |> stream(:conversations, [], dom_id: &"conv-#{&1.id}")
      |> assign(:filter_status, "all")
      |> assign(:filter_inbox, nil)
      |> assign(:composer_mode, :reply)
      |> assign(:search, "")
      |> assign(:selected, nil)
      |> assign(:conv_topic, nil)
      |> assign(:messages, [])
      |> stream(:messages, [])
      |> assign(:message_form, to_form(%{"content" => ""}, as: "message"))
      |> assign(:search_form, to_form(%{"q" => ""}))

    if account do
      Phoenix.PubSub.subscribe(Chatwooter.PubSub, "account:#{account.id}")

      {:ok, assign(socket, :inboxes, Inboxes.list_inboxes(account))}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    status = if params["status"] in ~w(open pending resolved), do: params["status"], else: "all"

    inbox_id =
      if Enum.any?(socket.assigns.inboxes, &(to_string(&1.id) == params["inbox_id"])),
        do: params["inbox_id"],
        else: nil

    socket =
      socket
      |> assign(:filter_status, status)
      |> assign(:filter_inbox, inbox_id)
      |> load_conversations()

    select_conversation(socket, params["conversation_id"])
  end

  defp select_conversation(%{assigns: %{account: account}} = socket, id)
       when not is_nil(account) and not is_nil(id) do
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
     |> stream(:messages, conv.messages, reset: true)
     |> assign(:composer_mode, :reply)
     |> assign(:message_form, to_form(%{"content" => ""}, as: "message"))}
  end

  defp select_conversation(socket, _id) do
    if socket.assigns.conv_topic,
      do: Phoenix.PubSub.unsubscribe(Chatwooter.PubSub, socket.assigns.conv_topic)

    {:noreply,
     socket
     |> assign(:selected, nil)
     |> assign(:conv_topic, nil)
     |> assign(:messages, [])
     |> stream(:messages, [], reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply,
     socket
     |> assign(:search, q)
     |> assign(:search_form, to_form(%{"q" => q}))
     |> load_conversations()}
  end

  def handle_event("noop", _params, socket), do: {:noreply, socket}

  def handle_event("composer-mode", %{"mode" => mode}, socket) when mode in ~w(reply note) do
    {:noreply, assign(socket, :composer_mode, String.to_existing_atom(mode))}
  end

  def handle_event("send", %{"message" => %{"content" => content}}, socket) do
    content = String.trim(content)

    if content == "" do
      {:noreply, socket}
    else
      attrs = %{content: content, sender_id: socket.assigns.current_scope.user.id}

      {:ok, message} =
        if socket.assigns.composer_mode == :note do
          Conversations.add_message(
            socket.assigns.selected,
            Map.merge(attrs, %{private: true, message_type: "outgoing"})
          )
        else
          Conversations.send_message(socket.assigns.selected, attrs)
        end

      if socket.assigns.composer_mode == :reply and telegram_inbox?(socket.assigns.selected) do
        {:ok, _} = TelegramSender.enqueue(message)
      end

      {:noreply, assign(socket, :message_form, to_form(%{"content" => ""}, as: "message"))}
    end
  end

  def handle_event("set-status", %{"status" => status}, socket)
      when status in ~w(open pending resolved) do
    {:ok, updated} = Conversations.set_status(socket.assigns.selected, status)
    conv = Conversations.get_conversation!(socket.assigns.account, updated.id)

    {:noreply,
     socket
     |> assign(:selected, conv)
     |> assign(:messages, conv.messages)
     |> stream(:messages, conv.messages, reset: true)
     |> load_conversations()}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    socket =
      if socket.assigns.selected && message.conversation_id == socket.assigns.selected.id do
        socket
        |> update(:messages, &append_once(&1, message))
        |> stream_insert(:messages, message)
      else
        socket
      end

    {:noreply, load_conversations(socket)}
  end

  def handle_info({:message_updated, message}, socket) do
    socket =
      if socket.assigns.selected && message.conversation_id == socket.assigns.selected.id do
        socket
        |> update(:messages, &replace_message(&1, message))
        |> stream_insert(:messages, message)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:conversation_updated, _id}, socket) do
    socket =
      if socket.assigns.selected do
        conv = Conversations.get_conversation!(socket.assigns.account, socket.assigns.selected.id)

        socket
        |> assign(:selected, conv)
        |> assign(:messages, conv.messages)
        |> stream(:messages, conv.messages, reset: true)
      else
        socket
      end

    {:noreply, load_conversations(socket)}
  end

  defp append_once(messages, message) do
    if Enum.any?(messages, &(&1.id == message.id)), do: messages, else: messages ++ [message]
  end

  defp replace_message(messages, updated) do
    Enum.map(messages, fn
      %{id: id} when id == updated.id -> updated
      other -> other
    end)
  end

  defp load_conversations(%{assigns: %{account: nil}} = socket), do: socket

  defp load_conversations(socket) do
    conversations =
      Conversations.list_conversations(socket.assigns.account,
        status: socket.assigns.filter_status,
        search: socket.assigns.search,
        inbox_id: socket.assigns.filter_inbox
      )

    socket
    |> assign(:conversation_count, length(conversations))
    |> stream(:conversations, conversations, reset: true)
  end

  defp conversation_path(status, inbox_id, conversation_id \\ nil) do
    params = %{"status" => status}
    params = if inbox_id, do: Map.put(params, "inbox_id", inbox_id), else: params

    params =
      if conversation_id, do: Map.put(params, "conversation_id", conversation_id), else: params

    ~p"/app?#{params}"
  end

  defp status_badge(:open), do: "Open"
  defp status_badge(:pending), do: "Pending"
  defp status_badge(:resolved), do: "Resolved"

  defp contact_of(conv), do: conv.contact_inbox.contact

  defp telegram_inbox?(conv), do: conv.contact_inbox.inbox.channel_type == :telegram

  defp last_message(conv), do: List.last(conv.messages || [])

  defp last_message_text(conv) do
    case last_message(conv) do
      nil -> "—"
      %{private: true} -> "Private note"
      msg -> msg.content || "Attachment"
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
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="inbox-workspace" class="flex h-screen overflow-hidden bg-canvas text-ink">
        <AppShell.sidebar
          current_scope={@current_scope}
          account_name={@account && @account.name}
          active={:conversations}
          inboxes={@inboxes}
          filter_inbox={@filter_inbox}
        />

        <section
          id="conversation-list"
          class={[
            "w-full shrink-0 flex-col border-r border-line bg-surface sm:w-80 lg:w-96",
            @selected && "hidden lg:flex",
            !@selected && "flex"
          ]}
        >
          <div class="space-y-4 border-b border-line p-4">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold tracking-tight">Conversations</h2>
              <span class="rounded-full bg-highlight px-2 py-0.5 text-xs font-semibold">
                {@conversation_count}
              </span>
            </div>
            <.form for={@search_form} id="conversation-search" phx-change="search" phx-submit="noop">
              <.input
                field={@search_form[:q]}
                type="search"
                placeholder="Search conversations…"
                phx-debounce="300"
                class="w-full rounded-lg border border-line bg-canvas px-3 py-2 text-sm text-ink outline-none transition-colors focus:border-brand"
              />
            </.form>
            <div class="flex gap-1 text-xs font-semibold">
              <.link
                :for={s <- ["all", "open", "pending", "resolved"]}
                id={"filter-#{s}"}
                patch={conversation_path(s, @filter_inbox)}
                aria-current={if(@filter_status == s, do: "page")}
                class={[
                  "rounded-lg px-3 py-1.5 capitalize transition-colors",
                  (@filter_status == s && "bg-brand-soft text-brand-deep") ||
                    "text-ink hover:bg-highlight"
                ]}
              >
                {s}
              </.link>
            </div>
          </div>

          <div id="conversation-items" phx-update="stream" class="flex-1 overflow-y-auto">
            <div id="conversation-empty" class="hidden p-8 text-center text-sm opacity-70 only:block">
              <.icon name="hero-chat-bubble-left-right" class="mx-auto mb-3 size-8 text-brand" />
              <p class="font-semibold">No conversations yet</p>
              <p class="mt-1">New WhatsApp and Telegram messages will show up here.</p>
            </div>
            <.link
              :for={{id, conv} <- @streams.conversations}
              patch={conversation_path(@filter_status, @filter_inbox, conv.id)}
              id={id}
              class={[
                "block border-b border-line px-4 py-4 transition-colors hover:bg-highlight",
                @selected && @selected.id == conv.id && "bg-brand-soft"
              ]}
            >
              <div class="flex items-center gap-3">
                <span class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand-soft text-xs font-bold text-brand-deep">
                  {AppShell.initials(contact_of(conv).name)}
                </span>
                <div class="min-w-0 flex-1">
                  <div class="flex items-center justify-between gap-2">
                    <p class="truncate text-sm font-semibold">{contact_of(conv).name}</p>
                    <span class="shrink-0 text-xs opacity-60">{last_message_at(conv)}</span>
                  </div>
                  <div class="flex items-center justify-between gap-2">
                    <p class="truncate text-xs opacity-70">{last_message_text(conv)}</p>
                    <.icon
                      name={
                        if(conv.contact_inbox.inbox.channel_type == :telegram,
                          do: "hero-paper-airplane",
                          else: "hero-chat-bubble-left-right"
                        )
                      }
                      class="size-4 shrink-0 text-brand"
                    />
                  </div>
                  <div class="mt-1 flex items-center gap-2 text-[11px] opacity-60">
                    <span>{conv.contact_inbox.inbox.name}</span><span>·</span><span>{status_badge(
                      conv.status
                    )}</span>
                  </div>
                </div>
              </div>
            </.link>
          </div>
        </section>

        <main class={["min-w-0 flex-1 flex-col", @selected && "flex", !@selected && "hidden lg:flex"]}>
          <div :if={!@selected} class="flex flex-1 items-center justify-center">
            <div class="text-center">
              <.icon name="hero-chat-bubble-left-right" class="mx-auto mb-3 size-10 text-brand" />
              <p class="text-sm font-semibold">Select a conversation</p>
              <p class="mt-1 text-xs opacity-70">Choose one from the list to start replying.</p>
            </div>
          </div>

          <div :if={@selected} class="flex min-h-0 flex-1 flex-col">
            <div
              id="conversation-header"
              class="flex flex-wrap items-center justify-between gap-3 border-b border-line bg-surface px-4 py-3"
            >
              <div class="flex min-w-0 items-center gap-3">
                <.link
                  patch={conversation_path(@filter_status, @filter_inbox)}
                  class="rounded-lg p-1 hover:bg-highlight lg:hidden"
                  aria-label="Back to conversations"
                ><.icon name="hero-arrow-left" class="size-5" /></.link>
                <span class="flex size-9 shrink-0 items-center justify-center rounded-full bg-brand-soft text-sm font-bold text-brand-deep">
                  {AppShell.initials(contact_of(@selected).name)}
                </span>
                <div>
                  <p class="truncate text-sm font-semibold">{contact_of(@selected).name}</p>
                  <p class="text-xs opacity-70">
                    {"##{@selected.id}"} · {@selected.contact_inbox.inbox.name}
                  </p>
                </div>
              </div>
              <div class="flex gap-1 text-xs font-semibold">
                <button
                  :for={s <- ["open", "pending", "resolved"]}
                  phx-click="set-status"
                  phx-value-status={s}
                  class={[
                    "cursor-pointer rounded-lg px-2 py-1.5 capitalize transition-colors",
                    (@selected.status == String.to_existing_atom(s) && "bg-brand-soft text-brand-deep") ||
                      "hover:bg-highlight"
                  ]}
                >
                  {s}
                </button>
              </div>
            </div>

            <div
              id="thread"
              phx-update="stream"
              class="flex-1 space-y-3 overflow-y-auto bg-canvas px-4 py-6 sm:px-6"
            >
              <div
                :for={{id, msg} <- @streams.messages}
                id={id}
                class={["flex", (msg.message_type == :outgoing or msg.private) && "justify-end"]}
              >
                <div class={[
                  "max-w-xl",
                  msg.private && "bubble-private",
                  !msg.private && msg.message_type == :outgoing && "bubble-agent",
                  !msg.private && msg.message_type != :outgoing && "bubble-contact"
                ]}>
                  <img
                    :for={att <- msg.attachments}
                    src={att.url}
                    alt="attachment"
                    class="mb-2 max-h-64 rounded-lg"
                  />
                  <p :if={msg.private} class="mb-1 text-xs font-semibold">Private note</p>
                  <p class="text-sm">{msg.content}</p>
                  <p
                    :if={msg.status == :failed}
                    class="mt-1 text-right text-[10px] font-semibold text-danger"
                  >
                    Not delivered
                  </p>
                  <p class="mt-1 text-right text-[10px] opacity-60">
                    {Calendar.strftime(msg.inserted_at, "%d/%m %H:%M")}
                  </p>
                </div>
              </div>
            </div>

            <.form
              for={@message_form}
              id="composer"
              phx-submit="send"
              class="border-t border-line bg-surface p-4"
            >
              <div class="mb-3 flex gap-2 text-xs font-semibold">
                <button
                  id="composer-reply"
                  type="button"
                  phx-click="composer-mode"
                  phx-value-mode="reply"
                  class={[
                    "rounded-lg px-3 py-1.5 transition-colors",
                    @composer_mode == :reply && "bg-brand-soft text-brand-deep"
                  ]}
                >Reply</button>
                <button
                  id="composer-note"
                  type="button"
                  phx-click="composer-mode"
                  phx-value-mode="note"
                  class={[
                    "rounded-lg px-3 py-1.5 transition-colors",
                    @composer_mode == :note && "bg-note"
                  ]}
                >Private note</button>
              </div>
              <div class="flex items-end gap-2">
                <div class="flex-1">
                  <.input
                    field={@message_form[:content]}
                    type="textarea"
                    rows="2"
                    placeholder={
                      if(@composer_mode == :note, do: "Write a private note…", else: "Type a reply…")
                    }
                    class="w-full resize-none rounded-lg border border-line bg-canvas px-3 py-2 text-sm text-ink outline-none focus:border-brand"
                  />
                </div>
                <button
                  type="submit"
                  class="flex items-center gap-2 rounded-lg bg-brand px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-brand-strong disabled:opacity-50"
                >
                  {if(@composer_mode == :note, do: "Add note", else: "Send")}
                  <.icon name="hero-paper-airplane" class="size-4" />
                </button>
              </div>
            </.form>
          </div>
        </main>

        <aside
          id="contact-panel"
          class="hidden w-80 shrink-0 flex-col overflow-y-auto border-l border-line bg-surface p-5 xl:flex"
        >
          <div :if={@selected}>
            <h3 class="mb-6 text-sm font-semibold">Contact details</h3>
            <div class="flex flex-col items-center text-center">
              <span class="flex h-16 w-16 items-center justify-center rounded-full bg-brand-soft text-xl font-bold text-brand-deep">
                {AppShell.initials(contact_of(@selected).name)}
              </span>
              <p class="mt-3 text-sm font-semibold">{contact_of(@selected).name}</p>
              <p :if={contact_of(@selected).phone_number} class="text-xs opacity-70">
                {contact_of(@selected).phone_number}
              </p>
              <p :if={contact_of(@selected).email} class="text-xs opacity-70">
                {contact_of(@selected).email}
              </p>
            </div>
            <div class="mt-6 border-t border-line pt-5">
              <h4 class="mb-3 text-xs font-semibold uppercase tracking-wide opacity-60">
                Conversation
              </h4>
              <dl class="space-y-3 text-xs">
                <div class="flex justify-between gap-2">
                  <dt class="opacity-70">Channel</dt><dd class="font-semibold">
                    {@selected.contact_inbox.inbox.name}
                  </dd>
                </div>
                <div class="flex justify-between gap-2">
                  <dt class="opacity-70">Status</dt><dd class="font-semibold capitalize">
                    {status_badge(@selected.status)}
                  </dd>
                </div>
                <div class="flex justify-between gap-2">
                  <dt class="opacity-70">Messages</dt><dd class="font-semibold">
                    {length(@messages)}
                  </dd>
                </div>
                <div class="flex justify-between gap-2">
                  <dt class="opacity-70">Opened</dt><dd class="font-semibold">
                    {Calendar.strftime(@selected.inserted_at, "%d/%m/%Y")}
                  </dd>
                </div>
              </dl>
            </div>
            <.link
              navigate={~p"/app/contacts/#{contact_of(@selected).id}"}
              class="mt-6 inline-flex items-center gap-2 text-xs font-semibold text-brand-deep hover:underline"
            >View contact <.icon name="hero-arrow-up-right" class="size-4" /></.link>
          </div>
          <div :if={!@selected} class="text-center text-xs opacity-70">
            Contact details will appear here.
          </div>
        </aside>
      </div>
    </Layouts.app>
    """
  end
end
