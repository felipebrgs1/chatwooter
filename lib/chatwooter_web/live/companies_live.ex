defmodule ChatwooterWeb.CompaniesLive do
  @moduledoc "Empresas estilo Chatwoot: cards + detalhe com contatos."
  use ChatwooterWeb, :live_view

  alias Chatwooter.{Accounts, Companies}
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
      |> assign(:search, "")
      |> assign(:modal_open, false)
      |> assign(:editing, nil)
      |> assign(
        :form,
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
     |> assign(:company_contacts, Companies.list_company_contacts(company))}
  end

  def handle_params(_params, _uri, %{assigns: %{account: account}} = socket)
      when not is_nil(account) do
    {:noreply,
     socket |> assign(:live_action, :index) |> assign(:company, nil) |> load_companies()}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
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
            assign(socket, :company, saved)
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

  def handle_event("delete", %{"id" => id}, %{assigns: %{account: account}} = socket) do
    account |> Companies.get_company!(id) |> Companies.delete_company()

    socket = socket |> load_companies() |> put_flash(:info, "Company deleted.")

    {:noreply,
     if(socket.assigns.live_action == :show,
       do: push_navigate(socket, to: ~p"/app/companies"),
       else: socket
     )}
  end

  defp load_companies(%{assigns: %{account: account, search: q}} = socket) do
    companies = Companies.list_companies(account)
    query = String.downcase(String.trim(q))

    filtered =
      if query == "" do
        companies
      else
        Enum.filter(companies, fn c ->
          String.contains?(String.downcase(c.name || ""), query) or
            String.contains?(String.downcase(c.domain || ""), query)
        end)
      end

    assign(socket, :companies, filtered)
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
        <header class="flex items-center justify-between border-b border-slate-200 bg-surface px-6 py-4">
          <div>
            <h2 class="text-base font-bold text-slate-900">Companies</h2>
            <p class="text-xs text-slate-500">{length(@companies)} companies</p>
          </div>
          <button
            id="new-company"
            phx-click="new"
            class="rounded-lg bg-brand px-4 py-2 text-sm font-semibold text-white hover:brightness-110"
          >
            New company
          </button>
        </header>

        <div class="border-b border-slate-200 bg-surface px-6 py-3">
          <form id="company-search" phx-change="search" phx-submit="noop">
            <input
              type="text"
              name="q"
              value={@search}
              placeholder="Search by name or domain…"
              phx-debounce="300"
              class="w-full max-w-md rounded-lg border border-slate-300 px-3 py-2 text-sm"
            />
          </form>
        </div>

        <div class="flex-1 overflow-y-auto p-6">
          <div id="companies" class="flex flex-col gap-4">
            <div class="hidden only:block rounded-xl border border-slate-200 bg-surface px-6 py-10 text-center text-sm text-slate-500">
              No companies yet. Click “New company” to add one.
            </div>
            <div
              :for={company <- @companies}
              id={"company-#{company.id}"}
              class="rounded-xl border border-slate-200 bg-surface px-5 py-4"
            >
              <div class="flex items-center gap-4">
                <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand/10 text-sm font-bold text-brand">
                  {AppShell.initials(company.name || "?")}
                </span>
                <div class="min-w-0 flex-1">
                  <div class="flex flex-wrap items-center gap-x-3">
                    <span class="truncate text-base font-medium text-slate-900">{company.name}</span>
                    <span :if={company.domain} class="truncate text-sm text-slate-500">
                      {company.domain}
                    </span>
                  </div>
                  <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
                    <span class="text-sm text-slate-500">
                      {company.contacts_count} {if company.contacts_count == 1,
                        do: "contact",
                        else: "contacts"}
                    </span>
                    <.link
                      navigate={~p"/app/companies/#{company.id}"}
                      class="text-xs font-semibold text-brand hover:underline"
                    >
                      View details
                    </.link>
                  </div>
                </div>
                <button
                  phx-click="edit"
                  phx-value-id={company.id}
                  class="text-xs font-semibold text-brand hover:underline"
                >
                  Edit
                </button>
                <button
                  phx-click="delete"
                  phx-value-id={company.id}
                  data-confirm="Delete this company? Contacts will be unlinked."
                  class="text-xs font-semibold text-danger hover:underline"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section
        :if={@live_action == :show && @company}
        class="flex min-w-0 flex-1 flex-col overflow-y-auto"
      >
        <div class="border-b border-slate-200 bg-surface px-6 py-4">
          <.link
            navigate={~p"/app/companies"}
            class="text-xs font-semibold text-brand hover:underline"
          >
            ← Back to companies
          </.link>
        </div>
        <div class="flex-1 space-y-4 p-6">
          <div id="company-detail" class="rounded-xl border border-slate-200 bg-surface p-6">
            <div class="flex items-center gap-4">
              <span class="flex h-14 w-14 shrink-0 items-center justify-center rounded-full bg-brand/10 text-lg font-bold text-brand">
                {AppShell.initials(@company.name || "?")}
              </span>
              <div class="min-w-0 flex-1">
                <h2 class="truncate text-lg font-bold text-slate-900">{@company.name}</h2>
                <p :if={@company.domain} class="truncate text-sm text-slate-500">{@company.domain}</p>
              </div>
              <button
                phx-click="edit"
                phx-value-id={@company.id}
                class="rounded-lg border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-600"
              >
                Edit
              </button>
            </div>
            <p :if={@company.description} class="mt-4 text-sm text-slate-700">
              {@company.description}
            </p>
            <dl class="mt-5 grid grid-cols-2 gap-4 text-sm">
              <div>
                <dt class="text-xs font-semibold uppercase tracking-wide text-slate-400">Contacts</dt>
                <dd class="mt-0.5 text-slate-900">{length(@company_contacts)}</dd>
              </div>
              <div>
                <dt class="text-xs font-semibold uppercase tracking-wide text-slate-400">Domain</dt>
                <dd class="mt-0.5 text-slate-900">{@company.domain || "—"}</dd>
              </div>
            </dl>
            <div class="mt-5">
              <button
                phx-click="delete"
                phx-value-id={@company.id}
                data-confirm="Delete this company? Contacts will be unlinked."
                class="rounded-lg border border-danger px-4 py-2 text-sm font-semibold text-danger hover:bg-danger hover:text-white"
              >
                Delete company
              </button>
            </div>
          </div>

          <div class="rounded-xl border border-slate-200 bg-surface p-6">
            <h3 class="mb-3 text-sm font-bold text-slate-900">Contacts</h3>
            <div :if={@company_contacts == []} class="text-sm text-slate-500">
              No contacts linked yet.
            </div>
            <div
              :for={contact <- @company_contacts}
              id={"member-#{contact.id}"}
              class="flex items-center justify-between gap-3 border-b border-slate-100 py-2.5 last:border-0"
            >
              <div class="flex min-w-0 items-center gap-3">
                <span class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-brand/10 text-xs font-bold text-brand">
                  {AppShell.initials(contact.name || "?")}
                </span>
                <div class="min-w-0">
                  <p class="truncate text-sm font-semibold text-slate-900">{contact.name}</p>
                  <p class="truncate text-xs text-slate-500">
                    {contact.phone_number || contact.email}
                  </p>
                </div>
              </div>
              <.link
                navigate={~p"/app/contacts/#{contact.id}"}
                class="shrink-0 text-xs font-semibold text-brand hover:underline"
              >
                Open
              </.link>
            </div>
          </div>
        </div>
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
