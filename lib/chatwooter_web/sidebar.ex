defmodule ChatwooterWeb.Sidebar do
  @moduledoc """
  Estado e navegação da sidebar — port de
  `chatwoot/app/javascript/dashboard/components-next/sidebar/Sidebar.vue`.

  Montado via `on_mount` no live_session autenticado: carrega conta, inboxes e
  disponibilidade do agente, acompanha a URL atual e trata os eventos
  `sidebar:*` do menu de perfil. A renderização fica em `ChatwooterWeb.Components.Sidebar.Sidebar`.
  """
  use ChatwooterWeb, :verified_routes

  import Phoenix.Component, only: [assign: 3, update: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, put_flash: 3]

  alias Chatwooter.{Accounts, Contacts, Inboxes}
  alias ChatwooterWeb.ComposeConversation

  # provider.js: DEFAULT_WIDTH, MIN_WIDTH, COLLAPSED_THRESHOLD, MAX_WIDTH
  @default_width 200
  @min_width 56
  @collapsed_threshold 160
  @max_width 320

  def on_mount(:default, _params, _session, socket) do
    user = socket.assigns.current_scope.user
    account = user |> Accounts.list_user_accounts() |> List.first()
    membership = account && Accounts.get_membership(account, user)

    sidebar = %{
      account: account,
      memberships: Accounts.list_user_memberships(user),
      inboxes: if(account, do: Inboxes.list_inboxes(account), else: []),
      teams: if(account, do: Accounts.list_user_teams(account, user), else: []),
      labels: if(account, do: Contacts.list_sidebar_labels(account), else: []),
      folders:
        if(account,
          do: Accounts.list_custom_filters(socket.assigns.current_scope, account),
          else: []
        ),
      availability: if(membership, do: membership.availability, else: :offline),
      auto_offline: if(membership, do: membership.auto_offline, else: false),
      width: clamp_width((user.ui_settings || %{})["sidebar_width"]),
      mobile?: false,
      uri: nil
    }

    {:cont,
     socket
     |> assign(:sidebar, sidebar)
     |> attach_hook(:sidebar_uri, :handle_params, &track_uri/3)
     |> attach_hook(:sidebar_events, :handle_event, &handle_event/3)
     |> ComposeConversation.attach()}
  end

  @doc "Recolhida = abaixo do limiar; no mobile a sidebar é sempre expandida (flyout)."
  def collapsed?(%{width: width, mobile?: mobile?}),
    do: not mobile? and width < @collapsed_threshold

  @doc "Recarrega as inboxes da sidebar (após criar/renomear/excluir uma inbox)."
  def refresh_inboxes(%{assigns: %{sidebar: %{account: nil}}} = socket), do: socket

  def refresh_inboxes(%{assigns: %{sidebar: %{account: account}}} = socket) do
    update(socket, :sidebar, &%{&1 | inboxes: Inboxes.list_inboxes(account)})
  end

  defp track_uri(_params, uri, socket) do
    {:cont, update(socket, :sidebar, &%{&1 | uri: URI.parse(uri)})}
  end

  defp handle_event("sidebar:set_availability", %{"availability" => availability}, socket) do
    {:halt, save_availability(socket, %{"availability" => availability})}
  end

  defp handle_event("sidebar:toggle_auto_offline", _params, socket) do
    {:halt, save_availability(socket, %{"auto_offline" => !socket.assigns.sidebar.auto_offline})}
  end

  # Durante o arraste o hook só avisa ao cruzar o limiar (troca de layout);
  # ao soltar manda `save`, e abaixo do limiar encaixa no mínimo (onResizeEnd).
  defp handle_event("sidebar:resize", %{"width" => width} = params, socket) do
    width = clamp_width(width)

    if params["save"] do
      width = if width < @collapsed_threshold, do: @min_width, else: width
      {:halt, save_width(socket, width)}
    else
      {:halt, update(socket, :sidebar, &%{&1 | width: width})}
    end
  end

  defp handle_event("sidebar:toggle_collapse", _params, socket) do
    width =
      if socket.assigns.sidebar.width < @collapsed_threshold, do: @default_width, else: @min_width

    {:halt, save_width(socket, width)}
  end

  defp handle_event("sidebar:viewport", %{"mobile" => mobile?}, socket) do
    {:halt, update(socket, :sidebar, &%{&1 | mobile?: mobile? == true})}
  end

  defp handle_event(_event, _params, socket), do: {:cont, socket}

  defp save_width(socket, width) do
    {:ok, _user} =
      Accounts.update_ui_settings(socket.assigns.current_scope.user, %{"sidebar_width" => width})

    update(socket, :sidebar, &%{&1 | width: width})
  end

  defp clamp_width(width) when is_number(width),
    do: width |> round() |> max(@min_width) |> min(@max_width)

  defp clamp_width(_width), do: @default_width

  defp save_availability(%{assigns: %{sidebar: %{account: account}}} = socket, attrs) do
    case account &&
           Accounts.update_availability(account, socket.assigns.current_scope.user, attrs) do
      {:ok, membership} ->
        update(
          socket,
          :sidebar,
          &%{&1 | availability: membership.availability, auto_offline: membership.auto_offline}
        )

      _error ->
        put_flash(socket, :error, "Could not update your availability")
    end
  end

  @doc """
  Árvore de navegação no formato do `menuItems` do Chatwoot. Só entram itens com
  rota existente — o Chatwoot também esconde grupos sem filhos acessíveis.

  Folhas com `exact: true` só ficam ativas na rota exata; as demais também
  cobrem sub-rotas (ex.: `/app/contacts/:id` ativa "All Contacts").
  """
  #
  # Ícones lucide do Chatwoot trocados pelo equivalente Phosphor mais próximo
  # (user-round-check e clock-alert não existem no Phosphor).
  def menu(%{inboxes: inboxes} = sidebar) do
    [
      %{
        name: "conversation",
        label: "Conversations",
        icon: "ph-chat-circle",
        children: [
          %{
            name: "all-conversations",
            label: "All Conversations",
            icon: "ph-tray",
            to: ~p"/app",
            exact: true
          },
          %{
            name: "mentions",
            label: "Mentions",
            icon: "ph-at",
            to: ~p"/app?conversation_type=mention"
          },
          %{
            name: "participating",
            label: "Participating",
            icon: "ph-user-circle",
            to: ~p"/app?conversation_type=participating"
          },
          %{
            name: "unattended",
            label: "Unattended",
            icon: "ph-clock-countdown",
            to: ~p"/app?conversation_type=unattended"
          },
          %{
            name: "folders",
            label: "Folders",
            icon: "ph-folder",
            collapsible: true,
            tree_line: true,
            children:
              Enum.map(Map.get(sidebar, :folders, []), fn folder ->
                %{
                  name: "folder-#{folder.id}",
                  label: folder.name,
                  to: ~p"/app?folder_id=#{folder.id}"
                }
              end)
          },
          %{
            name: "teams",
            label: "Teams",
            icon: "ph-users",
            collapsible: true,
            tree_line: true,
            children:
              Enum.map(Map.get(sidebar, :teams, []), fn team ->
                %{name: "team-#{team.id}", label: team.name, to: ~p"/app?team_id=#{team.id}"}
              end)
          },
          %{
            name: "channels",
            label: "Channels",
            icon: "ph-broadcast",
            collapsible: true,
            tree_line: true,
            children:
              Enum.map(inboxes, fn inbox ->
                %{
                  name: "inbox-#{inbox.id}",
                  label: inbox.name,
                  inbox: inbox,
                  to: ~p"/app?inbox_id=#{inbox.id}"
                }
              end)
          },
          %{
            name: "labels",
            label: "Labels",
            icon: "ph-tag",
            collapsible: true,
            tree_line: true,
            children:
              Enum.map(Map.get(sidebar, :labels, []), fn label ->
                %{
                  name: "label-#{label.id}",
                  label: label.title,
                  color: label.color,
                  to: ~p"/app?label=#{label.title}"
                }
              end)
          }
        ]
      },
      %{
        name: "contacts",
        label: "Contacts",
        icon: "ph-address-book",
        children: [%{name: "all-contacts", label: "All Contacts", to: ~p"/app/contacts"}]
      },
      %{
        name: "companies",
        label: "Companies",
        icon: "ph-buildings",
        children: [%{name: "all-companies", label: "All Companies", to: ~p"/app/companies"}]
      },
      %{
        name: "settings",
        label: "Settings",
        icon: "ph-lightning",
        children: [
          %{
            name: "settings-account",
            label: "Account Settings",
            icon: "ph-briefcase",
            to: ~p"/app/settings",
            exact: true
          },
          %{
            name: "settings-agents",
            label: "Agents",
            icon: "ph-user-square",
            to: ~p"/app/settings/agents"
          },
          %{
            name: "settings-inboxes",
            label: "Inboxes",
            icon: "ph-tray",
            to: ~p"/app/settings/inboxes"
          }
        ]
      }
    ]
  end

  @doc "Filhos que aparecem: subgrupos sem folhas somem, como no `visibleChildren` do Chatwoot."
  def visible_children(%{children: children}) do
    Enum.reject(children, &match?(%{children: []}, &1))
  end

  @doc "Folhas navegáveis de um grupo (subgrupos achatados)."
  def leaves(%{children: children}), do: Enum.flat_map(children, &Map.get(&1, :children, [&1]))

  @doc """
  Nome da folha ativa para a URL atual. Entre as que casam, vence a mais
  específica (mais query params, depois o path mais longo) — equivale ao
  ranking por `activeOn`/params do `activeChild` no `SidebarGroup.vue`.
  """
  def active_leaf(_menu, nil), do: nil

  def active_leaf(menu, %URI{path: path, query: query}) do
    current_query = URI.decode_query(query || "")

    menu
    |> Enum.flat_map(&leaves/1)
    |> Enum.map(&{&1, URI.parse(&1.to)})
    |> Enum.filter(fn {leaf, to} ->
      path_matches?(leaf, to.path, path) and query_matches?(to, current_query)
    end)
    |> Enum.max_by(
      fn {_leaf, to} -> {map_size(URI.decode_query(to.query || "")), byte_size(to.path)} end,
      fn -> nil end
    )
    |> case do
      {leaf, _to} -> leaf.name
      nil -> nil
    end
  end

  defp path_matches?(%{exact: true}, leaf_path, path), do: path == leaf_path

  defp path_matches?(_leaf, leaf_path, path),
    do: path == leaf_path or String.starts_with?(path, leaf_path <> "/")

  defp query_matches?(%URI{query: query}, current_query) do
    query
    |> Kernel.||("")
    |> URI.decode_query()
    |> Enum.all?(fn {k, v} -> current_query[k] == v end)
  end

  @doc "Atributos do link de uma folha: `patch` no mesmo LiveView (mesmo path), senão `navigate`."
  def leaf_nav(to, current_path) do
    if current_path && URI.parse(to).path == current_path, do: [patch: to], else: [navigate: to]
  end
end
