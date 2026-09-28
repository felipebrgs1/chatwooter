defmodule ChatwooterWeb.ConversationsLive.Index do
  @moduledoc "Inbox unificada estilo Chatwoot: sidebar + lista + thread + painel do contato."
  use ChatwooterWeb, :live_view

  alias Chatwooter.{Accounts, Conversations, Inboxes}
  alias Chatwooter.Workers.TelegramSender
  alias ChatwooterWeb.Components.Conversation.{ChatListHeader, ChatTypeTabs}
  alias ChatwooterWeb.ConversationsLive.{BulkActions, CardActions, FilterEditor}

  import CardActions, only: [conversation_path: 1, conversation_path: 2]

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
      |> assign(:view, %{})
      |> assign(:folder, nil)
      |> FilterEditor.mount()
      |> CardActions.mount()
      |> BulkActions.mount()
      |> assign(:view_title, "Conversations")
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
    socket = socket |> assign_folder(params["folder_id"]) |> FilterEditor.from_params(params)

    {view, title} =
      if socket.assigns.folder do
        {%{"folder_id" => to_string(socket.assigns.folder.id)}, socket.assigns.folder.name}
      else
        if socket.assigns.advanced_query do
          {%{"filters" => params["filters"]}, "Conversations"}
        else
          parse_view(params, socket.assigns)
        end
      end

    {:noreply, socket} =
      socket
      |> assign(:view, view)
      |> assign(:view_title, title)
      |> select_conversation(params["conversation_id"])

    {:noreply, load_conversations(socket)}
  end

  defp assign_folder(socket, nil), do: assign(socket, :folder, nil)

  defp assign_folder(socket, id) do
    folder =
      with account when not is_nil(account) <- socket.assigns.account,
           {id, ""} <- Integer.parse(id),
           %{filter_type: 0} = folder <-
             Accounts.get_custom_filter(socket.assigns.current_scope, account, id) do
        folder
      else
        _ -> nil
      end

    socket = assign(socket, :folder, folder)
    if folder, do: socket, else: put_flash(socket, :error, "Folder not found")
  end

  # Visões do conversation.routes.js do Chatwoot (inbox, time, etiqueta,
  # mentions/participating/unattended) viram query params de /app. Params
  # inválidos são ignorados. O título segue a precedência do pageTitle (ChatList.vue).
  @conversation_types %{
    "mention" => "Mentions",
    "participating" => "Participating",
    "unattended" => "Unattended"
  }

  defp parse_view(_params, %{account: nil}), do: {%{}, "Conversations"}

  defp parse_view(params, %{account: account, inboxes: inboxes}) do
    inbox = Enum.find(inboxes, &(to_string(&1.id) == params["inbox_id"]))
    team = find_team(account, params["team_id"])
    label = if params["label"] not in [nil, ""], do: params["label"]

    type =
      if Map.has_key?(@conversation_types, params["conversation_type"]),
        do: params["conversation_type"]

    view =
      %{
        "inbox_id" => inbox && to_string(inbox.id),
        "team_id" => team && to_string(team.id),
        "label" => label,
        "conversation_type" => type
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    {view, view_title(inbox, team, label, type)}
  end

  defp view_title(%{name: name}, _team, _label, _type), do: name
  defp view_title(nil, %{name: name}, _label, _type), do: name
  defp view_title(nil, nil, label, _type) when is_binary(label), do: "#" <> label
  defp view_title(nil, nil, nil, type), do: Map.get(@conversation_types, type, "Conversations")

  defp find_team(account, id) when is_binary(id) do
    case Integer.parse(id) do
      {id, ""} -> Accounts.get_team(account, id)
      _ -> nil
    end
  end

  defp find_team(_account, _id), do: nil

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

  defp load_conversations(%{assigns: assigns} = socket)
       when not is_nil(assigns.folder) or not is_nil(assigns.advanced_query) do
    opts = [
      user_id: socket.assigns.current_scope.user.id,
      assignee_type: socket.assigns.assignee_tab,
      sort_by: socket.assigns.chat_sort
    ]

    query = (assigns.folder && assigns.folder.query) || assigns.advanced_query

    case Conversations.filter_conversations(socket.assigns.account, query, opts) do
      {:ok, %{conversations: conversations, counts: counts}} ->
        socket
        |> assign(:conversation_count, length(conversations))
        |> assign(:tab_counts, counts)
        |> BulkActions.listed(conversations)
        |> stream(:conversations, conversations, reset: true)

      {:error, _} ->
        socket
        |> assign(:conversation_count, 0)
        |> assign(:tab_counts, %{mine: 0, unassigned: 0, all: 0})
        |> BulkActions.listed([])
        |> stream(:conversations, [], reset: true)
        |> put_flash(:error, "This folder contains unsupported or invalid filters")
    end
  end

  defp load_conversations(socket) do
    %{account: account, current_scope: %{user: user}} = socket.assigns
    %{view: view} = socket.assigns

    filters = [
      status: socket.assigns.chat_status,
      inbox_id: view["inbox_id"],
      team_id: view["team_id"],
      label: view["label"],
      conversation_type: view["conversation_type"]
    ]

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
    |> BulkActions.listed(conversations)
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

  defp status_badge(:open), do: "Open"
  defp status_badge(:pending), do: "Pending"
  defp status_badge(:resolved), do: "Resolved"
  defp status_badge(:snoozed), do: "Snoozed"

  defp contact_of(conv), do: conv.contact_inbox.contact

  defp telegram_inbox?(conv), do: conv.contact_inbox.inbox.channel_type == :telegram
end
