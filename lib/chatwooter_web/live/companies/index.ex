defmodule ChatwooterWeb.CompaniesLive.Index do
  @moduledoc "Lista de empresas estilo Chatwoot (cards). O detalhe fica em `CompaniesLive.Show`."
  use ChatwooterWeb, :live_view

  alias Chatwooter.{Accounts, Companies}

  on_mount ChatwooterWeb.CompaniesLive.FormModal

  @impl true
  def mount(_params, _session, socket) do
    account = Accounts.list_user_accounts(socket.assigns.current_scope.user) |> List.first()

    socket =
      socket
      |> assign(:account, account)
      |> assign(:companies, [])
      |> assign(:sort_by, "name")
      |> assign(:sort_order, "asc")
      |> assign(:filter_has_contacts, "")
      |> assign(:show_filter_drawer, false)
      |> assign(:search, "")

    {:ok, if(account, do: load_companies(socket), else: socket)}
  end

  @impl true
  def handle_event("toggle-filter-drawer", _params, socket) do
    {:noreply, assign(socket, :show_filter_drawer, !socket.assigns.show_filter_drawer)}
  end

  def handle_event("update-sort", %{"sort" => sort, "order" => order}, socket) do
    socket =
      socket
      |> assign(:sort_by, sort)
      |> assign(:sort_order, order)
      |> load_companies()

    {:noreply, socket}
  end

  def handle_event("apply-filters", params, socket) do
    socket =
      socket
      |> assign(:filter_has_contacts, params["has_contacts"] || "")
      |> load_companies()

    {:noreply, socket}
  end

  def handle_event("clear-filters", _params, socket) do
    socket =
      socket
      |> assign(:filter_has_contacts, "")
      |> load_companies()

    {:noreply, socket}
  end

  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:search, q) |> load_companies()}
  end

  def handle_event("delete", %{"id" => id}, %{assigns: %{account: account}} = socket) do
    account |> Companies.get_company!(id) |> Companies.delete_company()
    {:noreply, socket |> load_companies() |> put_flash(:info, "Company deleted.")}
  end

  @impl true
  def handle_info({:company_saved, _company}, socket), do: {:noreply, load_companies(socket)}

  defp load_companies(socket) do
    account = socket.assigns.account
    q = socket.assigns[:search] || ""
    sort_by = socket.assigns[:sort_by] || "name"
    sort_order = socket.assigns[:sort_order] || "asc"
    filter_has_contacts = socket.assigns[:filter_has_contacts] || ""

    companies = Companies.list_companies(account)
    query = String.downcase(String.trim(q))

    filtered =
      companies
      |> Enum.filter(fn c ->
        matches_query?(c, query) and matches_has_contacts?(c, filter_has_contacts)
      end)
      |> sort_companies(sort_by, sort_order)

    assign(socket, :companies, filtered)
  end

  defp matches_query?(_company, ""), do: true

  defp matches_query?(company, query) do
    String.contains?(String.downcase(company.name || ""), query) or
      String.contains?(String.downcase(company.domain || ""), query)
  end

  defp matches_has_contacts?(_company, ""), do: true
  defp matches_has_contacts?(company, "with_contacts"), do: (company.contacts_count || 0) > 0
  defp matches_has_contacts?(company, "no_contacts"), do: (company.contacts_count || 0) == 0
  defp matches_has_contacts?(_company, _), do: true

  defp sort_companies(companies, "name", "desc"),
    do: Enum.sort_by(companies, &(&1.name || ""), :desc)

  defp sort_companies(companies, "name", _), do: Enum.sort_by(companies, &(&1.name || ""), :asc)

  defp sort_companies(companies, "domain", "desc"),
    do: Enum.sort_by(companies, &(&1.domain || ""), :desc)

  defp sort_companies(companies, "domain", _),
    do: Enum.sort_by(companies, &(&1.domain || ""), :asc)

  defp sort_companies(companies, "contacts_count", "asc"),
    do: Enum.sort_by(companies, &(&1.contacts_count || 0), :asc)

  defp sort_companies(companies, "contacts_count", _),
    do: Enum.sort_by(companies, &(&1.contacts_count || 0), :desc)

  defp sort_companies(companies, "created_at", "asc"),
    do: Enum.sort_by(companies, & &1.inserted_at, {:asc, DateTime})

  defp sort_companies(companies, _, _),
    do: Enum.sort_by(companies, & &1.inserted_at, {:desc, DateTime})
end
