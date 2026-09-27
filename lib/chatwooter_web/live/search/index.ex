defmodule ChatwooterWeb.SearchLive.Index do
  @moduledoc """
  Busca global — port de `chatwoot/app/javascript/dashboard/modules/search/components/SearchView.vue`
  (rota `accounts/:accountId/search/:tab?`). Aqui a aba vai na query (`?q=...&tab=...`),
  como as demais visões do app, para manter uma rota por LiveView.

  Artigos da central de ajuda ficam de fora (fora do escopo v1). As buscas recentes
  do Chatwoot vivem no localStorage (`recentSearches`); aqui vão em
  `users.ui_settings["recent_searches"]`, que é onde o app guarda preferências de UI.
  """
  use ChatwooterWeb, :live_view

  alias Chatwooter.{Accounts, Contacts, Conversations}

  @types ~w(contacts conversations messages)
  @per_page 15
  @all_tab_limit 5
  @max_recent_searches 3

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    account = user |> Accounts.list_user_accounts() |> List.first()
    recent = (user.ui_settings || %{})["recent_searches"]

    {:ok,
     socket
     |> assign(:page_title, "Search")
     |> assign(:account, account)
     |> assign(:query, "")
     |> assign(:tab, "all")
     |> assign(:recent_searches, if(is_list(recent), do: recent, else: []))
     |> reset_results()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = String.trim(params["q"] || "")
    tab = if params["tab"] in @types, do: params["tab"], else: "all"

    socket =
      if query != socket.assigns.query or not socket.assigns.searched? do
        socket |> assign(:query, query) |> full_search()
      else
        socket
      end

    {:noreply, assign(socket, :tab, tab)}
  end

  @impl true
  def handle_event("search", %{"q" => value}, socket) do
    # SearchInput.vue: só busca com 2+ caracteres ou só dígitos (id da conversa)
    query = if String.length(value) > 1 or value =~ ~r/^[0-9]+$/, do: value, else: ""

    {:noreply, socket |> add_recent_search(query) |> patch_search(query, socket.assigns.tab)}
  end

  def handle_event("select_recent_search", %{"q" => query}, socket) do
    {:noreply,
     socket
     |> add_recent_search(query)
     |> push_event("search:set-query", %{q: query})
     |> patch_search(query, socket.assigns.tab)}
  end

  def handle_event("clear_recent_searches", _params, socket) do
    {:noreply, save_recent_searches(socket, [])}
  end

  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, patch_search(socket, socket.assigns.query, tab)}
  end

  def handle_event("load_more", _params, %{assigns: %{tab: tab}} = socket) when tab in @types do
    page = socket.assigns.pages[tab] + 1
    records = search(tab, socket.assigns.account, socket.assigns.query, page)

    {:noreply,
     socket
     |> update(:results, &Map.update!(&1, tab, fn current -> current ++ records end))
     |> update(:pages, &Map.put(&1, tab, page))
     |> update(:has_more, &Map.put(&1, tab, length(records) == @per_page))}
  end

  def handle_event("load_more", _params, socket), do: {:noreply, socket}

  defp patch_search(socket, query, tab) do
    params =
      [q: String.trim(query), tab: if(tab != "all", do: tab)]
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)

    push_patch(socket, to: ~p"/app/search?#{params}", replace: true)
  end

  defp reset_results(socket) do
    socket
    |> assign(:searched?, false)
    |> assign(:results, Map.new(@types, &{&1, []}))
    |> assign(:pages, Map.new(@types, &{&1, 1}))
    |> assign(:has_more, Map.new(@types, &{&1, false}))
  end

  defp full_search(%{assigns: %{query: ""}} = socket), do: reset_results(socket)
  defp full_search(%{assigns: %{account: nil}} = socket), do: reset_results(socket)

  defp full_search(%{assigns: %{account: account, query: query}} = socket) do
    results = Map.new(@types, &{&1, search(&1, account, query, 1)})

    socket
    |> reset_results()
    |> assign(:searched?, true)
    |> assign(:results, results)
    |> assign(
      :has_more,
      Map.new(results, fn {type, list} -> {type, length(list) == @per_page} end)
    )
  end

  defp search("contacts", account, query, page),
    do: Contacts.search_contacts(account, query, page)

  defp search("conversations", account, query, page),
    do: Conversations.search_conversations(account, query, page)

  defp search("messages", account, query, page),
    do: Conversations.search_messages(account, query, page)

  # RecentSearches.vue#addRecentSearch: 2+ caracteres, sem duplicar (ignora caixa), máx. 3
  defp add_recent_search(socket, query) do
    query = String.trim(query)

    if String.length(query) < 2 do
      socket
    else
      searches =
        [
          query
          | Enum.reject(
              socket.assigns.recent_searches,
              &(String.downcase(&1) == String.downcase(query))
            )
        ]
        |> Enum.take(@max_recent_searches)

      save_recent_searches(socket, searches)
    end
  end

  defp save_recent_searches(socket, searches) do
    {:ok, _user} =
      Accounts.update_ui_settings(socket.assigns.current_scope.user, %{
        "recent_searches" => searches
      })

    assign(socket, :recent_searches, searches)
  end

  ## Helpers do template (computeds do SearchView.vue)

  @doc false
  def tabs(results) do
    [
      %{value: "all", label: "All results", count: nil}
      | for {type, label} <- [
              {"contacts", "Contacts"},
              {"conversations", "Conversations"},
              {"messages", "Messages"}
            ] do
          count = length(results[type])
          %{value: type, label: label, count: if(count > 0, do: count)}
        end
    ]
  end

  @doc false
  def visible_records(records, "all"), do: Enum.take(records, @all_tab_limit)
  def visible_records(records, _tab), do: records

  @doc false
  def show_section?(tab, type), do: tab in ["all", type]

  @doc false
  def show_view_more?(records, tab), do: tab == "all" and length(records) > @all_tab_limit

  @doc false
  def total_count(results), do: results |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
end
