defmodule ChatwooterWeb.CompaniesLive do
  @moduledoc "Empresas estilo Chatwoot: cards + detalhe com contatos."
  use ChatwooterWeb, :live_view

  alias Chatwooter.{Accounts, Companies, Conversations}
  alias Chatwooter.Companies.Company
  alias ChatwooterWeb.AppShell

  @impl true
  def mount(_params, _session, socket) do
    account = Accounts.list_user_accounts(socket.assigns.current_scope.user) |> List.first()

    socket =
      socket
      |> assign(:account, account)
      |> assign(:companies, [])
      |> assign(:company, nil)
      |> assign(:company_contacts, [])
      |> assign(:company_conversations, [])
      |> assign(:active_tab, "contacts")
      |> assign(:sort_by, "name")
      |> assign(:sort_order, "asc")
      |> assign(:filter_has_contacts, "")
      |> assign(:show_filter_drawer, false)
      |> assign(:custom_form, to_form(%{"key" => "", "value" => ""}, as: "custom"))
      |> assign(:search, "")
      |> assign(:modal_open, false)
      |> assign(:editing, nil)
      |> assign(
        :form,
        to_form(%{"name" => "", "domain" => "", "description" => ""}, as: "company")
      )
      |> assign(
        :profile_form,
        to_form(%{"name" => "", "domain" => "", "description" => ""}, as: "company")
      )

    {:ok, if(account, do: load_companies(socket), else: socket)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, %{assigns: %{account: account}} = socket)
      when not is_nil(account) do
    company = Companies.get_company!(account, id)

    {:noreply,
     socket
     |> assign(:live_action, :show)
     |> assign(:company, company)
     |> assign(:active_tab, "contacts")
     |> assign(
       :profile_form,
       to_form(
         %{
           "name" => company.name || "",
           "domain" => company.domain || "",
           "description" => company.description || ""
         },
         as: "company"
       )
     )
     |> assign(:company_contacts, Companies.list_company_contacts(company))
     |> assign(
       :company_conversations,
       Conversations.list_company_conversations(account, company.id)
     )}
  end

  def handle_params(_params, _uri, %{assigns: %{account: account}} = socket)
      when not is_nil(account) do
    {:noreply,
     socket |> assign(:live_action, :index) |> assign(:company, nil) |> load_companies()}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle-filter-drawer", _params, socket) do
    {:noreply, assign(socket, :show_filter_drawer, !socket.assigns.show_filter_drawer)}
  end

  def handle_event("set-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
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

  def handle_event("new", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing, nil)
     |> assign(:modal_open, true)
     |> assign(
       :form,
       to_form(%{"name" => "", "domain" => "", "description" => ""}, as: "company")
     )}
  end

  def handle_event("profile-validate", %{"company" => params}, socket) do
    company = socket.assigns.company
    changeset = Companies.change_company(company, params)

    {:noreply,
     assign(socket, :profile_form, to_form(changeset, as: "company", action: :validate))}
  end

  def handle_event("profile-save", %{"company" => params}, socket) do
    company = socket.assigns.company

    case Companies.update_company(company, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:company, updated)
         |> assign(:company_contacts, Companies.list_company_contacts(updated))
         |> assign(
           :profile_form,
           to_form(
             %{
               "name" => updated.name || "",
               "domain" => updated.domain || "",
               "description" => updated.description || ""
             },
             as: "company"
           )
         )
         |> load_companies()
         |> put_flash(:info, "Company profile updated.")}

      {:error, changeset} ->
        {:noreply,
         assign(socket, :profile_form, to_form(changeset, as: "company", action: :validate))}
    end
  end

  def handle_event("edit", %{"id" => id}, %{assigns: %{account: account}} = socket) do
    company = Companies.get_company!(account, id)

    {:noreply,
     socket
     |> assign(:editing, company)
     |> assign(:modal_open, true)
     |> assign(
       :form,
       to_form(
         %{
           "name" => company.name || "",
           "domain" => company.domain || "",
           "description" => company.description || ""
         },
         as: "company"
       )
     )}
  end

  def handle_event("validate", %{"company" => params}, socket) do
    company = socket.assigns.editing || %Company{}

    {:noreply,
     assign(
       socket,
       :form,
       to_form(Companies.change_company(company, params), as: "company", action: :validate)
     )}
  end

  def handle_event("save", %{"company" => params}, %{assigns: %{account: account}} = socket) do
    result =
      case socket.assigns.editing do
        nil -> Companies.create_company(account, params)
        company -> Companies.update_company(company, params)
      end

    case result do
      {:ok, saved} ->
        socket =
          socket
          |> assign(:editing, nil)
          |> assign(:modal_open, false)
          |> load_companies()
          |> put_flash(:info, "Company saved.")

        socket =
          if socket.assigns.live_action == :show do
            socket
            |> assign(:company, saved)
            |> assign(:company_contacts, Companies.list_company_contacts(saved))
          else
            socket
          end

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "company", action: :validate))}
    end
  end

  def handle_event("close-modal", _params, socket) do
    {:noreply, socket |> assign(:modal_open, false) |> assign(:editing, nil)}
  end

  def handle_event("add-custom-attr", %{"custom" => %{"key" => key, "value" => value}}, socket) do
    key = String.trim(key || "")

    if key == "" do
      {:noreply, put_flash(socket, :error, "Attribute name can't be blank.")}
    else
      {:ok, company} = Companies.set_custom_attribute(socket.assigns.company, key, value || "")

      {:noreply,
       socket
       |> assign(:company, company)
       |> assign(:custom_form, to_form(%{"key" => "", "value" => ""}, as: "custom"))
       |> put_flash(:info, "Attribute saved.")}
    end
  end

  def handle_event("remove-custom-attr", %{"key" => key}, socket) do
    {:ok, company} = Companies.remove_custom_attribute(socket.assigns.company, key)

    {:noreply, socket |> assign(:company, company) |> put_flash(:info, "Attribute removed.")}
  end

  def handle_event("delete", %{"id" => id}, %{assigns: %{account: account}} = socket) do
    account |> Companies.get_company!(id) |> Companies.delete_company()

    socket = socket |> load_companies() |> put_flash(:info, "Company deleted.")

    {:noreply,
     if(socket.assigns.live_action == :show,
       do: push_navigate(socket, to: ~p"/app/companies"),
       else: socket
     )}
  end

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

  defp format_date(nil), do: "—"
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y")

  defp last_active([]), do: "—"

  defp last_active([conv | _]) do
    case conv.updated_at do
      %DateTime{} = dt -> time_ago(dt)
      _ -> "—"
    end
  end

  defp time_ago(%DateTime{} = dt) do
    seconds = DateTime.diff(DateTime.utc_now(), dt)

    cond do
      seconds < 60 -> "just now"
      seconds < 3600 -> "#{div(seconds, 60)}m ago"
      seconds < 86_400 -> "#{div(seconds, 3600)}h ago"
      true -> "#{div(seconds, 86_400)}d ago"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen overflow-hidden bg-canvas">
      <AppShell.sidebar
        current_scope={@current_scope}
        account_name={@account && @account.name}
        active={:companies}
      />

      <section :if={@live_action == :index} class="flex min-w-0 flex-1 flex-col">
        <!-- Header 1:1 Chatwoot CompaniesListLayout / CompanyHeader.vue -->
        <header class="sticky top-0 z-20 border-b border-line bg-surface/90 px-6 backdrop-blur-sm">
          <div class="mx-auto flex w-full max-w-5xl items-center justify-between gap-4 py-4">
            <div class="flex items-center gap-3 min-w-0">
              <h2 class="truncate text-xl font-bold tracking-tight text-ink">Companies</h2>
              <span class="rounded-full bg-highlight px-2.5 py-0.5 text-xs font-semibold text-ink/70">
                {length(@companies)}
              </span>
            </div>

            <div class="flex items-center gap-3">
              <!-- Search Input 1:1 -->
              <form id="company-search" phx-change="search" phx-submit="noop" class="relative w-64">
                <.icon
                  name="hero-magnifying-glass"
                  class="pointer-events-none absolute left-3 top-2.5 size-4 text-ink/40"
                />
                <input
                  type="search"
                  name="q"
                  value={@search}
                  placeholder="Search companies..."
                  phx-debounce="300"
                  class="h-9 w-full rounded-lg border border-line bg-canvas pl-9 pr-3 text-sm text-ink outline-none transition placeholder:text-ink/40 focus:border-brand focus:ring-1 focus:ring-brand"
                />
              </form>

              <!-- Botão Filtro estilo Chatwoot -->
              <button
                type="button"
                id="toggle-company-filter"
                phx-click="toggle-filter-drawer"
                class={[
                  "relative flex size-9 items-center justify-center rounded-lg border text-ink/70 transition hover:bg-highlight hover:text-ink",
                  if(@filter_has_contacts != "" or @show_filter_drawer,
                    do: "border-brand bg-brand-soft text-brand-deep",
                    else: "border-line bg-surface"
                  )
                ]}
                title="Filters"
              >
                <.icon name="hero-funnel" class="size-4" />
                <span
                  :if={@filter_has_contacts != ""}
                  class="absolute -right-1 -top-1 size-2 rounded-full bg-brand"
                />
              </button>

              <!-- Sort Menu Dropdown -->
              <div class="flex items-center rounded-lg border border-line bg-surface p-0.5">
                <button
                  type="button"
                  phx-click="update-sort"
                  phx-value-sort={@sort_by}
                  phx-value-order={if(@sort_order == "asc", do: "desc", else: "asc")}
                  class="flex h-8 items-center gap-1.5 px-2.5 text-xs font-medium text-ink/70 hover:text-ink"
                  title="Toggle order"
                >
                  <.icon
                    name={
                      if(@sort_order == "asc", do: "hero-bars-arrow-up", else: "hero-bars-arrow-down")
                    }
                    class="size-3.5"
                  />
                  <span class="capitalize">{@sort_by}</span>
                </button>
              </div>

              <!-- New Company Button -->
              <button
                id="new-company"
                phx-click="new"
                class="rounded-lg bg-brand px-3.5 py-2 text-xs font-semibold text-white shadow-sm transition hover:brightness-110"
              >
                New company
              </button>
            </div>
          </div>
        </header>

        <!-- Drawer de Filtros de Companies -->
        <div
          :if={@show_filter_drawer}
          id="company-filter-drawer"
          class="border-b border-line bg-surface px-6 py-4 transition-all"
        >
          <div class="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4">
            <div class="flex flex-wrap items-center gap-3">
              <span class="text-xs font-bold uppercase tracking-wider text-ink/50">Filter by:</span>

              <form
                id="filter-contacts-count-form"
                phx-change="apply-filters"
                class="flex items-center gap-2"
              >
                <select
                  name="has_contacts"
                  class="h-8 rounded-lg border border-line bg-canvas px-2.5 text-xs text-ink outline-none focus:border-brand"
                >
                  <option value="">All companies</option>
                  <option value="with_contacts" selected={@filter_has_contacts == "with_contacts"}>
                    Has contacts
                  </option>
                  <option value="no_contacts" selected={@filter_has_contacts == "no_contacts"}>
                    No contacts
                  </option>
                </select>
              </form>

              <button
                :if={@filter_has_contacts != ""}
                phx-click="clear-filters"
                class="inline-flex items-center gap-1 rounded-lg px-2 py-1 text-xs font-medium text-danger hover:underline"
              >
                <.icon name="hero-x-mark" class="size-3.5" /> Clear filters
              </button>
            </div>

            <!-- Botões de ordenação rápida -->
            <div class="flex items-center gap-1 text-xs text-ink/60">
              <span class="mr-1">Sort:</span>
              <button
                type="button"
                phx-click="update-sort"
                phx-value-sort="name"
                phx-value-order={@sort_order}
                class={[
                  "rounded px-2 py-1 transition",
                  @sort_by == "name" && "bg-brand-soft font-semibold text-brand-deep"
                ]}
              >
                Name
              </button>
              <button
                type="button"
                phx-click="update-sort"
                phx-value-sort="domain"
                phx-value-order={@sort_order}
                class={[
                  "rounded px-2 py-1 transition",
                  @sort_by == "domain" && "bg-brand-soft font-semibold text-brand-deep"
                ]}
              >
                Domain
              </button>
              <button
                type="button"
                phx-click="update-sort"
                phx-value-sort="contacts_count"
                phx-value-order={@sort_order}
                class={[
                  "rounded px-2 py-1 transition",
                  @sort_by == "contacts_count" && "bg-brand-soft font-semibold text-brand-deep"
                ]}
              >
                Contacts
              </button>
              <button
                type="button"
                phx-click="update-sort"
                phx-value-sort="created_at"
                phx-value-order={@sort_order}
                class={[
                  "rounded px-2 py-1 transition",
                  @sort_by == "created_at" && "bg-brand-soft font-semibold text-brand-deep"
                ]}
              >
                Created
              </button>
            </div>
          </div>
        </div>

        <!-- Lista de Cards 1:1 estilo CompaniesCard.vue -->
        <main class="flex-1 overflow-y-auto px-6 py-6">
          <div class="mx-auto w-full max-w-5xl">
            <div id="companies" class="flex flex-col gap-3">
              <div class="hidden only:block rounded-xl border border-line bg-surface px-6 py-16 text-center">
                <span class="mx-auto flex size-12 items-center justify-center rounded-full bg-brand-soft text-brand">
                  <.icon name="hero-building-office" class="size-6" />
                </span>
                <h3 class="mt-3 text-sm font-semibold text-ink">No companies found</h3>
                <p class="mt-1 text-xs text-ink/50">
                  Try adjusting your search or filters, or add a new company.
                </p>
                <button
                  type="button"
                  phx-click="new"
                  class="mt-4 rounded-lg bg-brand px-4 py-2 text-xs font-semibold text-white shadow-sm hover:brightness-110"
                >
                  Create company
                </button>
              </div>

              <!-- Card de Empresa 1:1 -->
              <div
                :for={company <- @companies}
                id={"company-#{company.id}"}
                class="group rounded-xl border border-line bg-surface p-4 shadow-sm transition hover:border-brand/40 hover:shadow-md"
              >
                <div class="flex items-center justify-between gap-4">
                  <div class="flex min-w-0 flex-1 items-center gap-3.5">
                    <span class="flex size-11 shrink-0 items-center justify-center rounded-full bg-brand-soft text-sm font-bold text-brand-deep ring-1 ring-brand/10">
                      {AppShell.initials(company.name || "?")}
                    </span>

                    <div class="min-w-0 flex-1">
                      <div class="flex flex-wrap items-center gap-x-2.5">
                        <span class="truncate text-sm font-bold text-ink">{company.name}</span>
                        <span
                          :if={company.domain}
                          class="inline-flex items-center gap-1 font-mono text-xs text-ink/60"
                        >
                          <.icon name="hero-globe-alt" class="size-3 text-ink/40" />
                          {company.domain}
                        </span>
                      </div>

                      <div class="mt-1 flex flex-wrap items-center gap-x-3 text-xs text-ink/60">
                        <span class="font-medium text-ink/80">
                          {company.contacts_count} {if company.contacts_count == 1,
                            do: "contact",
                            else: "contacts"}
                        </span>
                        <span class="text-ink/20">•</span>
                        <.link
                          navigate={~p"/app/companies/#{company.id}"}
                          class="font-semibold text-brand hover:underline"
                        >
                          View details
                        </.link>
                      </div>
                    </div>
                  </div>

                  <div class="flex items-center gap-2">
                    <button
                      phx-click="edit"
                      phx-value-id={company.id}
                      class="rounded-lg p-1.5 text-xs font-semibold text-ink/60 transition hover:bg-highlight hover:text-ink"
                    >
                      Edit
                    </button>
                    <button
                      phx-click="delete"
                      phx-value-id={company.id}
                      data-confirm="Delete this company? Contacts will be unlinked."
                      class="rounded-lg p-1.5 text-xs font-semibold text-danger/80 transition hover:bg-danger/10 hover:text-danger"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </main>
      </section>

      <!-- Detalhes da Empresa 1:1 estilo CompanyDetailView.vue / CompaniesDetailsLayout.vue -->
      <section
        :if={@live_action == :show && @company}
        class="flex min-w-0 flex-1 overflow-hidden bg-canvas"
      >
        <!-- Layout principal (Centro: Perfil da Empresa e Edição) -->
        <div class="flex min-w-0 flex-1 flex-col overflow-y-auto">
          <!-- Top bar / Header com Breadcrumbs -->
          <header class="sticky top-0 z-10 border-b border-line bg-surface/90 px-6 py-4 backdrop-blur-sm">
            <div class="mx-auto flex max-w-2xl items-center justify-between gap-4">
              <nav class="flex items-center gap-2 text-sm text-ink/60">
                <.link
                  navigate={~p"/app/companies"}
                  class="font-medium hover:text-brand hover:underline"
                >
                  Companies
                </.link>
                <span class="text-ink/30">/</span>
                <span class="truncate font-semibold text-ink">{@company.name}</span>
              </nav>

              <button
                phx-click="edit"
                phx-value-id={@company.id}
                class="rounded-lg border border-line bg-surface px-3 py-1.5 text-xs font-semibold text-ink/80 transition hover:bg-highlight"
              >
                Edit company
              </button>
            </div>
          </header>

          <main class="mx-auto w-full max-w-2xl px-6 py-8">
            <div id="company-detail" class="flex flex-col items-start gap-8">
              <!-- Top Avatar & Name Info -->
              <div id="company-profile" class="flex w-full items-center justify-between gap-4">
                <div class="flex items-center gap-4">
                  <span class="flex size-16 shrink-0 items-center justify-center rounded-full bg-brand-soft text-2xl font-bold text-brand ring-1 ring-brand/10">
                    {AppShell.initials(@company.name || "?")}
                  </span>
                  <div class="min-w-0">
                    <h3 class="truncate text-xl font-bold text-ink">{@company.name}</h3>
                    <div class="mt-1 flex flex-wrap items-center gap-x-2 text-xs text-ink/60">
                      <span
                        :if={@company.domain}
                        class="inline-flex items-center gap-1 font-mono text-ink/80"
                      >
                        <.icon name="hero-globe-alt" class="size-3.5 text-ink/50" />
                        {@company.domain}
                      </span>
                      <span :if={@company.domain}>•</span>
                      <span>Created {format_date(@company.inserted_at)}</span>
                      <span>•</span>
                      <span>Last active {last_active(@company_conversations)}</span>
                    </div>
                  </div>
                </div>

                <button
                  phx-click="edit"
                  phx-value-id={@company.id}
                  class="rounded-lg border border-line bg-surface px-3 py-1.5 text-xs font-semibold text-ink/80 transition hover:bg-highlight"
                >
                  Edit
                </button>
              </div>

              <!-- Formulário de Edição Direta 1:1 estilo CompanyProfileCard.vue -->
              <div id="company-profile-card" class="w-full">
                <.form
                  for={@profile_form}
                  id="company-profile-form"
                  phx-change="profile-validate"
                  phx-submit="profile-save"
                  class="flex flex-col gap-4 [&_.fieldset]:mb-0 [&_.label]:mb-0.5 [&_.label]:text-xs [&_.label]:font-medium [&_.label]:text-ink/70 [&_input]:h-9 [&_input]:text-sm"
                >
                  <div class="flex items-center justify-between">
                    <span class="text-xs font-bold uppercase tracking-wider text-ink/50">Company Profile</span>
                  </div>

                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <.input
                      field={@profile_form[:name]}
                      id="profile_company_name"
                      type="text"
                      label="Company name"
                      placeholder="Company name"
                    />
                    <.input
                      field={@profile_form[:domain]}
                      id="profile_company_domain"
                      type="text"
                      label="Website domain"
                      placeholder="acme.com"
                    />
                  </div>

                  <div>
                    <.input
                      field={@profile_form[:description]}
                      id="profile_company_description"
                      type="textarea"
                      label="Description"
                      placeholder="Brief summary about the company..."
                    />
                  </div>

                  <div class="flex justify-end">
                    <button
                      type="submit"
                      class="rounded-lg bg-brand px-4 py-1.5 text-xs font-semibold text-white shadow-sm hover:brightness-110"
                    >
                      Save changes
                    </button>
                  </div>
                </.form>
              </div>

              <!-- Quick Info Grid -->
              <div class="grid w-full grid-cols-2 gap-3 sm:grid-cols-4">
                <div class="rounded-xl border border-line bg-surface p-3.5">
                  <span class="text-[11px] font-semibold uppercase tracking-wider text-ink/50">Contacts</span>
                  <p class="mt-1 text-lg font-bold text-ink">{length(@company_contacts)}</p>
                </div>
                <div class="rounded-xl border border-line bg-surface p-3.5">
                  <span class="text-[11px] font-semibold uppercase tracking-wider text-ink/50">Conversations</span>
                  <p class="mt-1 text-lg font-bold text-ink">{length(@company_conversations)}</p>
                </div>
                <div class="rounded-xl border border-line bg-surface p-3.5 sm:col-span-2">
                  <span class="text-[11px] font-semibold uppercase tracking-wider text-ink/50">Domain</span>
                  <p class="mt-1 truncate font-mono text-sm font-semibold text-ink">
                    {@company.domain || "—"}
                  </p>
                </div>
              </div>

              <!-- Custom Attributes Section -->
              <div class="w-full rounded-xl border border-line bg-surface p-5">
                <h4 class="text-xs font-bold uppercase tracking-wider text-ink/50">
                  Custom Attributes
                </h4>
                <div
                  :if={@company.custom_attributes == %{}}
                  class="py-4 text-center text-xs text-ink/50"
                >
                  No custom attributes yet.
                </div>
                <div
                  :for={{key, value} <- @company.custom_attributes}
                  id={"custom-#{key}"}
                  class="flex items-center justify-between border-b border-line py-2.5 text-xs last:border-0"
                >
                  <p class="truncate">
                    <span class="font-semibold text-ink">{key}:</span>
                    <span class="text-ink/70">{value}</span>
                  </p>
                  <button
                    phx-click="remove-custom-attr"
                    phx-value-key={key}
                    class="shrink-0 text-xs font-semibold text-danger hover:underline"
                  >
                    Remove
                  </button>
                </div>
                <.form
                  for={@custom_form}
                  id="custom-form"
                  phx-submit="add-custom-attr"
                  class="mt-4 flex items-end gap-2 border-t border-line pt-4 [&_.fieldset]:mb-0 [&_.label]:mb-0.5 [&_.label]:text-xs [&_.label]:font-medium [&_.label]:text-ink/70 [&_input]:h-8 [&_input]:text-xs"
                >
                  <.input
                    field={@custom_form[:key]}
                    type="text"
                    label="Key"
                    placeholder="e.g. industry"
                  />
                  <.input
                    field={@custom_form[:value]}
                    type="text"
                    label="Value"
                    placeholder="e.g. tech"
                  />
                  <button
                    type="submit"
                    class="rounded-lg bg-brand px-3 py-1.5 text-xs font-semibold text-white shadow-sm hover:brightness-110"
                  >
                    Add
                  </button>
                </.form>
              </div>

              <!-- Delete Company Section -->
              <div class="w-full border-t border-line pt-6">
                <div class="flex items-center justify-between">
                  <div>
                    <h5 class="text-sm font-semibold text-ink">Delete Company</h5>
                    <p class="text-xs text-ink/60">
                      Permanently delete this company. Contacts will be unlinked.
                    </p>
                  </div>
                  <button
                    type="button"
                    phx-click="delete"
                    phx-value-id={@company.id}
                    data-confirm="Delete this company? Contacts will be unlinked."
                    class="rounded-lg border border-danger/40 px-3.5 py-1.5 text-xs font-semibold text-danger hover:bg-danger hover:text-white"
                  >
                    Delete company
                  </button>
                </div>
              </div>
            </div>
          </main>
        </div>

        <!-- Sidebar na Direita (estilo Chatwoot Desktop Sidebar: History & Contacts) -->
        <aside
          id="company-detail-sidebar"
          class="hidden w-96 shrink-0 flex-col border-l border-line bg-surface lg:flex"
        >
          <!-- TabBar estilo Chatwoot -->
          <div class="border-b border-line p-4">
            <div class="flex rounded-lg bg-canvas p-1">
              <button
                type="button"
                phx-click="set-tab"
                phx-value-tab="history"
                class={[
                  "flex-1 rounded-md py-1.5 text-xs font-medium transition",
                  if(@active_tab == "history",
                    do: "bg-surface font-semibold text-ink shadow-sm",
                    else: "text-ink/60 hover:text-ink"
                  )
                ]}
              >
                History ({length(@company_conversations)})
              </button>
              <button
                type="button"
                phx-click="set-tab"
                phx-value-tab="contacts"
                class={[
                  "flex-1 rounded-md py-1.5 text-xs font-medium transition",
                  if(@active_tab == "contacts",
                    do: "bg-surface font-semibold text-ink shadow-sm",
                    else: "text-ink/60 hover:text-ink"
                  )
                ]}
              >
                Contacts ({length(@company_contacts)})
              </button>
            </div>
          </div>

          <!-- Conteúdo da Sidebar de acordo com a aba -->
          <div class="min-h-0 flex-1 overflow-y-auto p-4">
            <!-- Aba: Histórico de Conversas da Empresa (CompanyHistorySidebar.vue) -->
            <div :if={@active_tab == "history"} id="company-conversations" class="space-y-3">
              <div :if={@company_conversations == []} class="py-12 text-center text-sm text-ink/50">
                No conversations yet.
              </div>
              <div
                :for={conv <- @company_conversations}
                id={"history-#{conv.id}"}
                class="group flex flex-col gap-2 rounded-xl border border-line p-3 transition hover:border-brand/40 hover:bg-canvas"
              >
                <div class="flex items-center justify-between">
                  <span class="inline-flex items-center gap-1.5 text-xs font-semibold text-ink">
                    <.icon name="hero-chat-bubble-left-right" class="size-3.5 text-brand" />
                    {conv.contact_inbox.contact.name}
                  </span>
                  <span class={[
                    "rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wider",
                    case conv.status do
                      "open" -> "bg-brand/10 text-brand"
                      "resolved" -> "bg-wa/10 text-wa"
                      _ -> "bg-highlight text-ink/70"
                    end
                  ]}>
                    {conv.status}
                  </span>
                </div>
                <div class="flex items-center justify-between text-xs text-ink/50">
                  <span>via {conv.contact_inbox.inbox.name}</span>
                  <.link
                    navigate={~p"/app?conversation_id=#{conv.id}"}
                    class="font-semibold text-brand hover:underline"
                  >
                    Open →
                  </.link>
                </div>
              </div>
            </div>

            <!-- Aba: Contatos Vinculados (CompanyContactsSidebar.vue) -->
            <div :if={@active_tab == "contacts"} id="company-contacts" class="space-y-3">
              <div :if={@company_contacts == []} class="py-12 text-center text-sm text-ink/50">
                No contacts linked yet.
              </div>
              <div
                :for={contact <- @company_contacts}
                id={"member-#{contact.id}"}
                class="flex items-center justify-between rounded-xl border border-line p-3 transition hover:border-brand/40 hover:bg-canvas"
              >
                <div class="flex min-w-0 items-center gap-3">
                  <span class="flex size-8 items-center justify-center rounded-full bg-brand-soft text-xs font-bold text-brand">
                    {AppShell.initials(contact.name || "?")}
                  </span>
                  <div class="min-w-0">
                    <p class="truncate text-xs font-semibold text-ink">{contact.name}</p>
                    <p class="truncate text-[11px] text-ink/50">
                      {contact.phone_number || contact.email || "No contact info"}
                    </p>
                  </div>
                </div>
                <.link
                  navigate={~p"/app/contacts/#{contact.id}"}
                  class="shrink-0 text-xs font-semibold text-brand hover:underline"
                >
                  View →
                </.link>
              </div>
            </div>
          </div>
        </aside>
      </section>

      <div
        :if={@modal_open}
        id="company-modal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-ink/50 p-4"
      >
        <div class="w-full max-w-md rounded-2xl bg-surface p-6 shadow-xl">
          <h3 class="mb-4 text-base font-bold text-slate-900">
            {if @editing, do: "Edit company", else: "New company"}
          </h3>
          <.form for={@form} id="company-form" phx-change="validate" phx-submit="save">
            <.input field={@form[:name]} type="text" label="Name" placeholder="Acme Inc" />
            <.input field={@form[:domain]} type="text" label="Domain" placeholder="acme.inc" />
            <.input
              field={@form[:description]}
              type="textarea"
              label="Description"
              placeholder="What do they do?"
            />
            <div class="mt-5 flex justify-end gap-2">
              <button
                type="button"
                phx-click="close-modal"
                class="rounded-lg border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-600"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="rounded-lg bg-brand px-4 py-2 text-sm font-semibold text-white hover:brightness-110"
              >
                Save
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
