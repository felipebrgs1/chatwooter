defmodule ChatwooterWeb.ConversationsLive.BulkActions do
  @moduledoc """
  Selection and bulk actions of the conversation list (`useBulkActions` + `ChatList.vue`).
  The listed conversations are kept in `@listed` so toggling a card re-inserts only it
  in the stream; every action clears the selection, and its broadcasts reload the list.
  """
  import Phoenix.Component, only: [assign: 3, update: 3]
  import Phoenix.LiveView
  import ChatwooterWeb.Components.Next.Avatar, only: [available_name: 1]

  alias Chatwooter.{Accounts, Contacts, Conversations}

  @menus %{
    "assign_labels" => :assign_labels,
    "remove_labels" => :remove_labels,
    "status" => :status,
    "agent" => :agent,
    "team" => :team
  }

  @statuses [
    {:resolved, "Resolve", "ph-check"},
    {:open, "Reopen", "ph-arrow-clockwise"},
    {:snoozed, "Snooze", "ph-alarm"}
  ]

  def mount(socket) do
    socket
    |> assign(:listed, [])
    |> assign(:bulk_selected, MapSet.new())
    |> reset_menu()
    |> attach_hook(:bulk_actions, :handle_event, &event/3)
  end

  @doc "Called after each list load: keeps the selection to conversations still listed."
  def listed(socket, conversations) do
    ids = MapSet.new(conversations, & &1.id)

    socket
    |> assign(:listed, conversations)
    |> update(:bulk_selected, &MapSet.intersection(&1, ids))
  end

  def all_selected?(listed, selected),
    do: listed != [] and MapSet.size(selected) == length(listed)

  @doc "Statuses offered: an action is hidden when every selected conversation already has it."
  def statuses(listed, selected) do
    current = for c <- listed, c.id in selected, uniq: true, do: c.status
    Enum.reject(@statuses, fn {status, _, _} -> current == [status] end)
  end

  defp event("bulk:toggle", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.listed, &(to_string(&1.id) == to_string(id))) do
      nil ->
        {:halt, socket}

      conv ->
        selected = socket.assigns.bulk_selected

        selected =
          if conv.id in selected,
            do: MapSet.delete(selected, conv.id),
            else: MapSet.put(selected, conv.id)

        {:halt, socket |> assign(:bulk_selected, selected) |> reset_menu() |> refresh([conv])}
    end
  end

  defp event("bulk:select_all", _, socket) do
    selected =
      if all_selected?(socket.assigns.listed, socket.assigns.bulk_selected),
        do: MapSet.new(),
        else: MapSet.new(socket.assigns.listed, & &1.id)

    {:halt,
     socket |> assign(:bulk_selected, selected) |> reset_menu() |> refresh(socket.assigns.listed)}
  end

  defp event("bulk:clear", _, socket), do: {:halt, clear(socket)}

  defp event("bulk:menu", %{"menu" => menu}, socket) when is_map_key(@menus, menu) do
    menu = @menus[menu]

    if socket.assigns.bulk_menu == menu,
      do: {:halt, reset_menu(socket)},
      else: {:halt, socket |> reset_menu() |> open_menu(menu)}
  end

  defp event("bulk:close_menu", _, socket), do: {:halt, reset_menu(socket)}

  defp event("bulk:toggle_label", %{"title" => title}, socket) do
    {:halt,
     update(socket, :bulk_picked, fn picked ->
       if title in picked, do: List.delete(picked, title), else: picked ++ [title]
     end)}
  end

  defp event("bulk:apply_labels", _, %{assigns: %{bulk_picked: [_ | _] = titles}} = socket) do
    %{account: account, bulk_menu: menu} = socket.assigns
    ids = MapSet.to_list(socket.assigns.bulk_selected)

    {result, ok, error} =
      if menu == :remove_labels,
        do:
          {Conversations.bulk_remove_labels(account, ids, titles), "Labels removed successfully.",
           "Failed to remove labels. Please try again."},
        else:
          {Conversations.bulk_add_labels(account, ids, titles), "Labels assigned successfully.",
           "Failed to assign labels. Please try again."}

    {:halt, finish(socket, result, ok, error)}
  end

  defp event("bulk:status", %{"status" => status}, socket) when status in ~w(open resolved) do
    ids = MapSet.to_list(socket.assigns.bulk_selected)

    {:halt,
     finish(
       socket,
       Conversations.bulk_set_status(socket.assigns.account, ids, status),
       "Conversation status updated successfully.",
       "Failed to update conversations. Please try again."
     )}
  end

  defp event("bulk:pick_agent", %{"id" => id}, socket),
    do: {:halt, pick(socket, socket.assigns.bulk_agents, id, &available_name/1)}

  defp event("bulk:pick_team", %{"id" => id}, socket),
    do: {:halt, pick(socket, socket.assigns.bulk_teams, id, & &1.name)}

  defp event("bulk:cancel", _, socket), do: {:halt, assign(socket, :bulk_pending, nil)}

  defp event("bulk:confirm", _, %{assigns: %{bulk_pending: %{} = pending}} = socket) do
    %{account: account, bulk_menu: menu} = socket.assigns
    ids = MapSet.to_list(socket.assigns.bulk_selected)

    result =
      if menu == :agent,
        do: Conversations.bulk_assign_agent(account, ids, pending.id),
        else: Conversations.bulk_assign_team(account, ids, pending.id)

    {ok, error} =
      if menu == :agent,
        do:
          {"Conversations assigned successfully.",
           "Failed to assign conversations. Please try again."},
        else: {"Teams assigned successfully.", "Failed to assign team. Please try again."}

    {:halt, finish(socket, result, ok, error)}
  end

  defp event("bulk:" <> _, _, socket), do: {:halt, socket}
  defp event(_, _, socket), do: {:cont, socket}

  defp open_menu(socket, menu) when menu in [:assign_labels, :remove_labels] do
    labels = Contacts.list_labels(socket.assigns.account)

    # BulkLabelActions.vue → visibleLabels: removing only offers labels on the selection.
    labels =
      if menu == :remove_labels do
        applied =
          for c <- socket.assigns.listed,
              c.id in socket.assigns.bulk_selected,
              title <- String.split(c.cached_label_list || "", ",", trim: true),
              into: MapSet.new(),
              do: String.trim(title)

        Enum.filter(labels, &(&1.title in applied))
      else
        labels
      end

    socket |> assign(:bulk_menu, menu) |> assign(:bulk_labels, labels)
  end

  defp open_menu(socket, :agent) do
    inbox_ids =
      for c <- socket.assigns.listed,
          c.id in socket.assigns.bulk_selected,
          uniq: true,
          do: c.inbox_id

    agents = Conversations.assignable_agents_for_inboxes(socket.assigns.account, inbox_ids)
    socket |> assign(:bulk_menu, :agent) |> assign(:bulk_agents, agents)
  end

  defp open_menu(socket, :team) do
    socket
    |> assign(:bulk_menu, :team)
    |> assign(:bulk_teams, Accounts.list_teams(socket.assigns.account))
  end

  defp open_menu(socket, :status), do: assign(socket, :bulk_menu, :status)

  defp pick(socket, _options, "none", _name),
    do: assign(socket, :bulk_pending, %{id: nil, name: "None"})

  defp pick(socket, options, id, name) do
    case Enum.find(options, &(to_string(&1.id) == id)) do
      nil -> socket
      option -> assign(socket, :bulk_pending, %{id: option.id, name: name.(option)})
    end
  end

  defp finish(socket, {:ok, _}, ok, _error), do: socket |> clear() |> put_flash(:info, ok)
  defp finish(socket, _result, _ok, error), do: socket |> reset_menu() |> put_flash(:error, error)

  defp clear(socket) do
    previously = socket.assigns.bulk_selected

    socket
    |> assign(:bulk_selected, MapSet.new())
    |> reset_menu()
    |> refresh(Enum.filter(socket.assigns.listed, &(&1.id in previously)))
  end

  defp reset_menu(socket) do
    socket
    |> assign(:bulk_menu, nil)
    |> assign(:bulk_picked, [])
    |> assign(:bulk_pending, nil)
    |> assign(:bulk_labels, [])
    |> assign(:bulk_agents, [])
    |> assign(:bulk_teams, [])
  end

  defp refresh(socket, conversations),
    do: Enum.reduce(conversations, socket, &stream_insert(&2, :conversations, &1))
end
