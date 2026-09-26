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
      |> assign(:custom_form, to_form(%{"key" => "", "value" => ""}, as: "custom"))
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

  defp format_date(nil), do: "—"
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y")

  defp last_active([]), do: "—"

  defp last_active([conv | _]) do
    case conv.updated_at do
      nil -> "—"
      dt -> time_ago(dt)
    end
  end

  defp time_ago(nil), do: "—"

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
            <p class="mt-3 text-xs text-slate-500">
              Created {format_date(@company.inserted_at)} · Last active {last_active(
                @company_conversations
              )}
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
              <div>
                <dt class="text-xs font-semibold uppercase tracking-wide text-slate-400">
                  Conversations
                </dt>
                <dd class="mt-0.5 text-slate-900">{length(@company_conversations)}</dd>
              </div>
              <div>
                <dt class="text-xs font-semibold uppercase tracking-wide text-slate-400">Created</dt>
                <dd class="mt-0.5 text-slate-900">{format_date(@company.inserted_at)}</dd>
              </div>
            </dl>
            <div class="mt-5 border-t border-slate-100 pt-4">
              <h4 class="mb-2 text-xs font-bold uppercase tracking-wide text-slate-400">
                Custom attributes
              </h4>
              <div :if={@company.custom_attributes == %{}} class="mb-2 text-xs text-slate-500">
                No custom attributes yet.
              </div>
              <div
                :for={{key, value} <- @company.custom_attributes}
                id={"custom-#{key}"}
                class="flex items-center justify-between gap-3 py-1 text-sm"
              >
                <p class="truncate"><span class="font-semibold">{key}:</span> {value}</p>
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
                class="mt-2 flex items-end gap-2"
              >
                <.input field={@custom_form[:key]} type="text" label="Name" placeholder="industry" />
                <.input field={@custom_form[:value]} type="text" label="Value" placeholder="tech" />
                <button
                  type="submit"
                  class="rounded-lg bg-brand px-3 py-2 text-sm font-semibold text-white hover:brightness-110"
                >
                  Add
                </button>
              </.form>
            </div>
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

          <div class="rounded-xl border border-slate-200 bg-surface p-6">
            <h3 class="mb-3 text-sm font-bold text-slate-900">Recent conversations</h3>
            <div :if={@company_conversations == []} class="text-sm text-slate-500">
              No conversations yet.
            </div>
            <div
              :for={conv <- @company_conversations}
              id={"history-#{conv.id}"}
              class="flex items-center justify-between gap-3 border-b border-slate-100 py-2.5 last:border-0"
            >
              <div class="min-w-0">
                <p class="truncate text-sm font-semibold text-slate-900">
                  {conv.contact_inbox.contact.name} via {conv.contact_inbox.inbox.name}
                </p>
                <p class="text-xs capitalize text-slate-500">
                  {conv.status} · {time_ago(conv.updated_at)}
                </p>
              </div>
              <.link
                navigate={~p"/app?conversation_id=#{conv.id}"}
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
