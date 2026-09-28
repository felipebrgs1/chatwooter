defmodule ChatwooterWeb.ConversationsLive.CardActions do
  @moduledoc """
  Context menu of the conversation card (`ConversationItem.vue` + the handlers `ChatList.vue`
  provides to it). Every change broadcasts `:conversation_updated`, which reloads the list.
  """
  use ChatwooterWeb, :verified_routes

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView

  import ChatwooterWeb.Components.Next.Avatar, only: [available_name: 1]

  alias Chatwooter.{Accounts, Contacts, Conversations}

  def mount(socket) do
    %{account: account, current_scope: %{user: user}} = socket.assigns
    membership = account && Accounts.get_membership(account, user)

    socket
    |> assign(:context_menu, nil)
    |> assign(:deleting_conversation, nil)
    |> assign(:admin?, membership != nil && membership.role == :administrator)
    |> attach_hook(:card_actions, :handle_event, &event/3)
  end

  @doc "Path of the list (or of a conversation in it) keeping the current view params."
  def conversation_path(view, conversation_id \\ nil) do
    params = if conversation_id, do: Map.put(view, "conversation_id", conversation_id), else: view

    if params == %{}, do: ~p"/app", else: ~p"/app?#{params}"
  end

  defp event("card:context_menu", %{"id" => id, "x" => x, "y" => y}, socket) do
    account = socket.assigns.account

    with {id, _} <- Integer.parse(to_string(id)),
         %{} = conv <- find_conversation(account, id) do
      conv = %{conv | unread_count: Conversations.count_unread(conv)}

      menu = %{
        conversation: conv,
        x: round(x),
        y: round(y),
        path: conversation_path(socket.assigns.view, conv.id),
        conversation_labels: Conversations.list_labels(conv),
        labels: Contacts.list_labels(account),
        agents: Conversations.assignable_agents(account, conv),
        teams: Accounts.list_teams(account)
      }

      {:halt, assign(socket, :context_menu, menu)}
    else
      _ -> {:halt, socket}
    end
  end

  defp event("card:close_menu", _, socket), do: {:halt, assign(socket, :context_menu, nil)}

  defp event("card:" <> action, _, %{assigns: %{context_menu: nil}} = socket)
       when action not in ~w(cancel_delete confirm_delete),
       do: {:halt, socket}

  # ChatList.vue → markAsUnread: also leaves the conversation, or opening it would read it again.
  defp event("card:mark_unread", _, socket) do
    conv = socket.assigns.context_menu.conversation
    {:ok, _} = Conversations.mark_unread(conv)
    {:halt, socket |> close() |> leave_if_open(conv)}
  end

  defp event("card:mark_read", _, socket) do
    conv = socket.assigns.context_menu.conversation
    {:ok, _} = Conversations.mark_seen(conv)
    send(self(), {:conversation_updated, conv.id})
    {:halt, close(socket)}
  end

  defp event("card:status", %{"status" => status}, socket)
       when status in ~w(open pending resolved) do
    case Conversations.set_status(socket.assigns.context_menu.conversation, status) do
      {:ok, _} -> {:halt, socket |> close() |> put_flash(:info, "Conversation status changed")}
      _ -> {:halt, socket |> close() |> put_flash(:error, "Conversation status change failed")}
    end
  end

  defp event("card:priority", %{"priority" => priority}, socket) do
    priority = if priority == "", do: nil, else: priority
    _ = Conversations.set_priority(socket.assigns.context_menu.conversation, priority)
    {:halt, close(socket)}
  end

  # Label toggles keep the menu open, like the `@mousedown.prevent` items of the original.
  defp event("card:label", %{"title" => title}, socket) do
    %{conversation: conv, conversation_labels: current} = socket.assigns.context_menu

    result =
      if title in current,
        do: Conversations.remove_label(conv, title),
        else: Conversations.add_label(socket.assigns.account, conv, title)

    case result do
      {:ok, labels} ->
        {:halt,
         assign(socket, :context_menu, %{
           socket.assigns.context_menu
           | conversation_labels: labels
         })}

      _ ->
        {:halt, put_flash(socket, :error, "Couldn't assign label. Please try again.")}
    end
  end

  defp event("card:agent", %{"id" => id}, socket) do
    %{conversation: conv, agents: agents} = socket.assigns.context_menu
    agent = Enum.find(agents, &(to_string(&1.id) == id))

    case Conversations.assign_agent(socket.assigns.account, conv, agent && agent.id) do
      {:ok, _} ->
        name = if agent, do: available_name(agent), else: "None"

        {:halt,
         socket
         |> close()
         |> put_flash(:info, ~s(Conversation id #{conv.display_id} assigned to "#{name}"))}

      _ ->
        {:halt,
         socket |> close() |> put_flash(:error, "Couldn't assign agent. Please try again.")}
    end
  end

  defp event("card:team", %{"id" => id}, socket) do
    %{conversation: conv, teams: teams} = socket.assigns.context_menu
    team = Enum.find(teams, &(to_string(&1.id) == id))

    case team && Conversations.assign_team(socket.assigns.account, conv, team.id) do
      {:ok, _} ->
        {:halt,
         socket
         |> close()
         |> put_flash(
           :info,
           ~s(Assigned team "#{team.name}" to conversation id #{conv.display_id})
         )}

      _ ->
        {:halt, socket |> close() |> put_flash(:error, "Couldn't assign team. Please try again.")}
    end
  end

  defp event("card:link_copied", _, socket),
    do: {:halt, socket |> close() |> put_flash(:info, "Conversation link copied to clipboard")}

  defp event("card:delete", _, %{assigns: %{admin?: true, context_menu: %{} = menu}} = socket) do
    {:halt, socket |> close() |> assign(:deleting_conversation, menu.conversation)}
  end

  defp event("card:cancel_delete", _, socket),
    do: {:halt, assign(socket, :deleting_conversation, nil)}

  defp event(
         "card:confirm_delete",
         _,
         %{assigns: %{admin?: true, deleting_conversation: %{} = conv}} = socket
       ) do
    socket = assign(socket, :deleting_conversation, nil)

    case Conversations.delete_conversation(conv) do
      {:ok, _} ->
        {:halt,
         socket
         |> put_flash(:info, "Conversation deleted successfully")
         |> leave_if_open(conv)}

      _ ->
        {:halt, put_flash(socket, :error, "Couldn't delete conversation! Try again")}
    end
  end

  defp event("card:" <> _, _, socket), do: {:halt, socket}
  defp event(_, _, socket), do: {:cont, socket}

  defp close(socket), do: assign(socket, :context_menu, nil)

  defp leave_if_open(%{assigns: %{selected: %{id: id}}} = socket, %{id: id}),
    do: push_patch(socket, to: conversation_path(socket.assigns.view))

  defp leave_if_open(socket, _conv), do: socket

  defp find_conversation(account, id) do
    Conversations.get_conversation!(account, id)
  rescue
    Ecto.NoResultsError -> nil
  end
end
