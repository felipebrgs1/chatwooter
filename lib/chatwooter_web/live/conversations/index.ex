defmodule ChatwooterWeb.ConversationsLive.Index do
  @moduledoc "Inbox unificada estilo Chatwoot: sidebar + lista + thread + painel do contato."
  use ChatwooterWeb, :live_view

  alias Chatwooter.{Accounts, Conversations, Inboxes}
  alias Chatwooter.Workers.TelegramSender
  alias ChatwooterWeb.Components.Conversation.{ChatListHeader, ChatTypeTabs}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    account = Accounts.list_user_accounts(user) |> List.first()

    socket =
      socket
      |> assign(:account, account)
      |> assign(:inboxes, [])
      |> assign(:conversation_count, 0)
      |> assign(:tab_counts, %{mine: 0, unassigned: 0, all: 0})
      |> stream(:conversations, [], dom_id: &"conv-#{&1.id}")
      |> assign(:filter_inbox, nil)
      |> assign_chat_filters(user)
      |> assign(:composer_mode, :reply)
      |> assign(:selected, nil)
      |> assign(:conv_topic, nil)
      |> assign(:messages, [])
      |> stream(:messages, [])
      |> assign(:message_form, to_form(%{"content" => ""}, as: "message"))

    if account do
      Phoenix.PubSub.subscribe(Chatwooter.PubSub, "account:#{account.id}")

      {:ok, assign(socket, :inboxes, Inboxes.list_inboxes(account))}
    else
      {:ok, socket}
    end
  end

  # Status e ordenação ficam em ui_settings.conversations_filter_by (como no
  # ConversationBasicFilter); a aba Mine/Unassigned/All só vive na página.
  defp assign_chat_filters(socket, user) do
    filter_by = (user.ui_settings || %{})["conversations_filter_by"] || %{}
    status = filter_by["status"]
    sort = filter_by["order_by"]

    socket
    |> assign(:assignee_tab, "me")
    |> assign(:chat_status, if(ChatListHeader.valid_status?(status), do: status, else: "open"))
    |> assign(
      :chat_sort,
      if(ChatListHeader.valid_sort?(sort), do: sort, else: "last_activity_at_desc")
    )
  end

  @impl true
  def handle_params(params, _uri, socket) do
    inbox_id =
      if Enum.any?(socket.assigns.inboxes, &(to_string(&1.id) == params["inbox_id"])),
        do: params["inbox_id"],
        else: nil

    {:noreply, socket} =
      socket
      |> assign(:filter_inbox, inbox_id)
      |> select_conversation(params["conversation_id"])

    {:noreply, load_conversations(socket)}
  end

  defp select_conversation(%{assigns: %{account: account}} = socket, id)
       when not is_nil(account) and not is_nil(id) do
    conv = Conversations.get_conversation!(account, id)
    {:ok, _} = Conversations.mark_seen(conv)

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
  def handle_event("chat:set_tab", %{"tab" => tab}, socket) do
    if ChatTypeTabs.valid_tab?(tab),
      do: {:noreply, socket |> assign(:assignee_tab, tab) |> load_conversations()},
      else: {:noreply, socket}
  end

  def handle_event("chat:set_status", %{"status" => status}, socket) do
    if ChatListHeader.valid_status?(status),
      do: {:noreply, socket |> assign(:chat_status, status) |> save_chat_filters()},
      else: {:noreply, socket}
  end

  def handle_event("chat:set_sort", %{"sort" => sort}, socket) do
    if ChatListHeader.valid_sort?(sort),
      do: {:noreply, socket |> assign(:chat_sort, sort) |> save_chat_filters()},
      else: {:noreply, socket}
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
        # conversa aberta na tela: a mensagem já foi vista
        {:ok, _} = Conversations.mark_seen(socket.assigns.selected)

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
    %{account: account, current_scope: %{user: user}} = socket.assigns
    filters = [status: socket.assigns.chat_status, inbox_id: socket.assigns.filter_inbox]

    conversations =
      Conversations.list_conversations(
        account,
        filters ++
          [
            assignee_type: socket.assigns.assignee_tab,
            user_id: user.id,
            sort_by: socket.assigns.chat_sort
          ]
      )

    socket
    |> assign(:conversation_count, length(conversations))
    |> assign(
      :tab_counts,
      Conversations.conversation_counts(account, [user_id: user.id] ++ filters)
    )
    |> stream(:conversations, conversations, reset: true)
  end

  defp save_chat_filters(socket) do
    {:ok, _} =
      Accounts.update_ui_settings(socket.assigns.current_scope.user, %{
        "conversations_filter_by" => %{
          "status" => socket.assigns.chat_status,
          "order_by" => socket.assigns.chat_sort
        }
      })

    load_conversations(socket)
  end

  defp conversation_path(inbox_id, conversation_id \\ nil) do
    params =
      %{"inbox_id" => inbox_id, "conversation_id" => conversation_id}
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    if params == %{}, do: ~p"/app", else: ~p"/app?#{params}"
  end

  defp list_title(%{filter_inbox: nil}), do: "Conversations"

  defp list_title(%{filter_inbox: inbox_id, inboxes: inboxes}) do
    case Enum.find(inboxes, &(to_string(&1.id) == inbox_id)) do
      nil -> "Conversations"
      inbox -> inbox.name
    end
  end

  defp status_badge(:open), do: "Open"
  defp status_badge(:pending), do: "Pending"
  defp status_badge(:resolved), do: "Resolved"
  defp status_badge(:snoozed), do: "Snoozed"

  defp contact_of(conv), do: conv.contact_inbox.contact

  defp telegram_inbox?(conv), do: conv.contact_inbox.inbox.channel_type == :telegram
end
