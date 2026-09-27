defmodule ChatwooterWeb.ContactsLive do
  @moduledoc "Contatos estilo Chatwoot: cards expansíveis + página de detalhe."
  use ChatwooterWeb, :live_view

  alias Chatwooter.Accounts
  alias Chatwooter.Companies
  alias Chatwooter.Contacts
  alias Chatwooter.Contacts.Contact
  alias Chatwooter.Conversations
  alias Chatwooter.Platform.RecordDeletion
  alias ChatwooterWeb.AppShell

  @impl true
  def mount(_params, _session, socket) do
    account = Accounts.list_user_accounts(socket.assigns.current_scope.user) |> List.first()

    socket =
      socket
      |> assign(:account, account)
      |> assign(:contacts, [])
      |> assign(:contact, nil)
      |> assign(:contact_conversations, [])
      |> assign(:contact_inboxes, [])
      |> assign(:active_tab, "history")
      |> assign(:search, "")
      |> assign(:sort_by, "name")
      |> assign(:sort_order, "asc")
      |> assign(:filter_channel, "")
      |> assign(:filter_company, "")
      |> assign(:filter_blocked, "")
      |> assign(:show_filter_drawer, false)
      |> assign(:inbox_options, [])
      |> assign(:company_options, [])
      |> assign(:expanded_id, nil)
      |> assign(:modal_open, false)
      |> assign(
        :form,
        to_form(%{"name" => "", "phone_number" => "", "email" => ""}, as: "contact")
      )
      |> assign(:quick_form, nil)

    {:ok, if(account, do: load_contacts(socket), else: socket)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, %{assigns: %{account: account}} = socket)
      when not is_nil(account) do
    contact = Contacts.get_contact!(account, id)

    {:noreply,
     socket
     |> assign(:live_action, :show)
     |> assign(:contact, contact)
     |> assign(:active_tab, "history")
     |> assign(:quick_form, to_form(flatten(contact), as: "contact"))
     |> assign(:contact_conversations, Conversations.list_contact_conversations(account, contact))
     |> assign(:contact_inboxes, Contacts.list_contact_inboxes(account, contact))}
  end

  def handle_params(_params, _uri, %{assigns: %{account: account}} = socket)
      when not is_nil(account) do
    {:noreply,
     socket
     |> assign(:live_action, :index)
     |> assign(:contact, nil)
     |> load_contacts()}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle-filter-drawer", _params, socket) do
    {:noreply, assign(socket, :show_filter_drawer, !socket.assigns.show_filter_drawer)}
  end

  def handle_event("update-sort", %{"sort" => sort, "order" => order}, socket) do
    socket =
      socket
      |> assign(:sort_by, sort)
      |> assign(:sort_order, order)
      |> load_contacts()

    {:noreply, socket}
  end

  def handle_event("apply-filters", params, socket) do
    socket =
      socket
      |> assign(:filter_channel, params["channel"] || "")
      |> assign(:filter_company, params["company"] || "")
      |> assign(:filter_blocked, params["blocked"] || "")
      |> load_contacts()

    {:noreply, socket}
  end

  def handle_event("clear-filters", _params, socket) do
    socket =
      socket
      |> assign(:filter_channel, "")
      |> assign(:filter_company, "")
      |> assign(:filter_blocked, "")
      |> load_contacts()

    {:noreply, socket}
  end

  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:search, q) |> load_contacts()}
  end

  def handle_event("new", _params, socket) do
    {:noreply,
     socket
     |> assign(:modal_open, true)
     |> assign(
       :form,
       to_form(%{"name" => "", "phone_number" => "", "email" => ""}, as: "contact")
     )}
  end

  def handle_event("validate", %{"contact" => params}, %{assigns: %{account: account}} = socket) do
    changeset =
      Contacts.change_contact(%Contact{account_id: account.id}, merge_extras(params, %{}))

    {:noreply, assign(socket, :form, to_form(changeset, as: "contact", action: :validate))}
  end

  def handle_event("save", %{"contact" => params}, %{assigns: %{account: account}} = socket) do
    {company_id, params} = Map.pop(params, "company_id")

    case Contacts.create_contact(account, merge_extras(params, %{})) do
      {:ok, contact} ->
        _linked = link_company(account, contact, company_id)

        {:noreply,
         socket
         |> assign(:modal_open, false)
         |> load_contacts()
         |> put_flash(:info, "Contact saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "contact", action: :validate))}
    end
  end

  def handle_event("set-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event(
        "toggle-block",
        _params,
        %{assigns: %{contact: contact}} = socket
      ) do
    new_blocked = !contact.blocked

    case Contacts.update_contact(contact, %{blocked: new_blocked}) do
      {:ok, updated} ->
        msg = if new_blocked, do: "Contact blocked.", else: "Contact unblocked."
        {:noreply, socket |> assign(:contact, updated) |> put_flash(:info, msg)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update contact status.")}
    end
  end

  def handle_event("close-modal", _params, socket) do
    {:noreply, assign(socket, :modal_open, false)}
  end

  def handle_event("toggle-expand", %{"id" => id}, socket) do
    expanded = socket.assigns.expanded_id == id
    contact = Contacts.get_contact!(socket.assigns.account, id)

    socket =
      if expanded do
        socket |> assign(:expanded_id, nil) |> assign(:quick_form, nil)
      else
        socket
        |> assign(:expanded_id, id)
        |> assign(:quick_form, to_form(flatten(contact), as: "contact"))
      end

    {:noreply, socket}
  end

  def handle_event("edit-details-save", %{"contact" => params}, socket) do
    account = socket.assigns.account
    contact = socket.assigns.contact
    {company_id, params} = Map.pop(params, "company_id")

    case Contacts.update_contact(contact, merge_extras(params, contact)) do
      {:ok, updated_contact} ->
        linked = link_company(account, updated_contact, company_id)

        {:noreply,
         socket
         |> assign(:contact, linked)
         |> assign(:quick_form, to_form(flatten(linked), as: "contact"))
         |> put_flash(:info, "Contact details updated.")}

      {:error, changeset} ->
        {:noreply,
         assign(socket, :quick_form, to_form(changeset, as: "contact", action: :validate))}
    end
  end

  def handle_event("edit-details-validate", %{"contact" => params}, socket) do
    contact = socket.assigns.contact
    changeset = Contacts.change_contact(contact, merge_extras(params, contact))

    {:noreply, assign(socket, :quick_form, to_form(changeset, as: "contact", action: :validate))}
  end

  def handle_event("quick-validate", %{"contact" => params}, socket) do
    contact = Contacts.get_contact!(socket.assigns.account, socket.assigns.expanded_id)
    changeset = Contacts.change_contact(contact, merge_extras(params, contact))

    {:noreply, assign(socket, :quick_form, to_form(changeset, as: "contact", action: :validate))}
  end

  def handle_event("quick-save", %{"contact" => params}, socket) do
    account = socket.assigns.account
    contact = Contacts.get_contact!(account, socket.assigns.expanded_id)
    {company_id, params} = Map.pop(params, "company_id")

    case Contacts.update_contact(contact, merge_extras(params, contact)) do
      {:ok, contact} ->
        updated = link_company(account, contact, company_id)

        socket =
          socket
          |> assign(:expanded_id, nil)
          |> assign(:quick_form, nil)
          |> load_contacts()

        socket =
          if socket.assigns.live_action == :show do
            assign(socket, :contact, updated)
          else
            socket
          end

        {:noreply, put_flash(socket, :info, "Contact updated.")}

      {:error, changeset} ->
        {:noreply,
         assign(socket, :quick_form, to_form(changeset, as: "contact", action: :validate))}
    end
  end

  def handle_event("delete", %{"id" => id}, %{assigns: %{account: account}} = socket) do
    RecordDeletion.delete_contact(account, id)

    socket =
      socket
      |> load_contacts()
      |> put_flash(:info, "Contact deleted.")

    {:noreply,
     if(socket.assigns.live_action == :show,
       do: push_navigate(socket, to: ~p"/app/contacts"),
       else: socket
     )}
  end

  defp load_contacts(socket) do
    account = socket.assigns.account
    q = socket.assigns[:search] || ""
    sort_by = socket.assigns[:sort_by] || "name"
    sort_order = socket.assigns[:sort_order] || "asc"
    filter_company = socket.assigns[:filter_company] || ""
    filter_blocked = socket.assigns[:filter_blocked] || ""

    contacts = Contacts.list_contacts(account)

    options =
      [{"No company", ""}] ++
        Enum.map(Companies.list_companies(account), &{&1.name, to_string(&1.id)})

    inboxes =
      [{"All channels", ""}] ++
        Enum.map(Chatwooter.Inboxes.list_inboxes(account), &{&1.name, to_string(&1.id)})

    socket =
      socket
      |> assign(:company_options, options)
      |> assign(:inbox_options, inboxes)

    query = String.downcase(String.trim(q))

    filtered =
      contacts
      |> Enum.filter(fn c ->
        matches_query?(c, query) and
          matches_company?(c, filter_company) and
          matches_blocked?(c, filter_blocked)
      end)
      |> sort_contacts(sort_by, sort_order)

    assign(socket, :contacts, filtered)
  end

  defp matches_query?(_contact, ""), do: true

  defp matches_query?(contact, query) do
    String.contains?(String.downcase(contact.name || ""), query) or
      String.contains?(String.downcase(contact.phone_number || ""), query) or
      String.contains?(String.downcase(contact.email || ""), query)
  end

  defp matches_company?(_contact, ""), do: true

  defp matches_company?(contact, company_id) do
    to_string(contact.company_id || "") == company_id
  end

  defp matches_blocked?(_contact, ""), do: true
  defp matches_blocked?(contact, "true"), do: contact.blocked == true
  defp matches_blocked?(contact, "false"), do: contact.blocked == false
  defp matches_blocked?(_contact, _), do: true

  defp sort_contacts(contacts, "name", "desc"),
    do: Enum.sort_by(contacts, &(&1.name || ""), :desc)

  defp sort_contacts(contacts, "name", _), do: Enum.sort_by(contacts, &(&1.name || ""), :asc)

  defp sort_contacts(contacts, "email", "desc"),
    do: Enum.sort_by(contacts, &(&1.email || ""), :desc)

  defp sort_contacts(contacts, "email", _), do: Enum.sort_by(contacts, &(&1.email || ""), :asc)

  defp sort_contacts(contacts, "created_at", "asc"),
    do: Enum.sort_by(contacts, & &1.inserted_at, {:asc, DateTime})

  defp sort_contacts(contacts, "created_at", _),
    do: Enum.sort_by(contacts, & &1.inserted_at, {:desc, DateTime})

  defp sort_contacts(contacts, "last_activity_at", "asc"),
    do:
      Enum.sort_by(contacts, &(&1.last_activity_at || ~U[1970-01-01 00:00:00Z]), {:asc, DateTime})

  defp sort_contacts(contacts, _, _),
    do:
      Enum.sort_by(
        contacts,
        &(&1.last_activity_at || ~U[1970-01-01 00:00:00Z]),
        {:desc, DateTime}
      )

  defp merge_extras(params, contact) do
    existing = contact_additional(contact)

    extra_params = %{
      "company_name" => "company",
      "city" => "city",
      "country" => "country",
      "description" => "description"
    }

    {extras, dropped} = additional_form_attributes(params, extra_params)
    social_profiles = social_form_attributes(params)

    additional =
      existing
      |> Map.merge(extras)
      |> Map.drop(dropped)
      |> then(fn attrs ->
        if map_size(social_profiles) > 0 or Map.has_key?(params, "social_linkedin") do
          Map.put(attrs, "social_profiles", social_profiles)
        else
          attrs
        end
      end)

    existing_custom = Map.get(contact, :custom_attributes) || %{}

    custom_attributes =
      case Jason.decode(params["custom_attributes_json"] || Jason.encode!(existing_custom)) do
        {:ok, attrs} when is_map(attrs) -> attrs
        _ -> existing_custom
      end

    params
    |> Map.drop(
      Map.values(extra_params) ++
        Enum.filter(Map.keys(params), &String.starts_with?(&1, "social_")) ++
        ["custom_attributes_json"]
    )
    |> Map.put("additional_attributes", additional)
    |> Map.put("custom_attributes", custom_attributes)
  end

  defp additional_form_attributes(params, extra_params) do
    extras =
      Map.new(extra_params, fn {key, param} -> {key, params[param]} end)
      |> Enum.reject(fn {_key, value} -> is_nil(value) or String.trim(value) == "" end)
      |> Map.new()

    dropped =
      Enum.filter(extra_params, fn {_key, param} ->
        Map.has_key?(params, param) and
          (is_nil(params[param]) or String.trim(params[param]) == "")
      end)
      |> Enum.map(&elem(&1, 0))

    {extras, dropped}
  end

  defp social_form_attributes(params) do
    params
    |> Enum.filter(fn {key, _value} -> String.starts_with?(key, "social_") end)
    |> Map.new(fn {key, value} -> {String.replace_prefix(key, "social_", ""), value} end)
    |> Enum.reject(fn {_key, value} -> is_nil(value) or String.trim(value) == "" end)
    |> Map.new()
  end

  defp contact_additional(%Contact{additional_attributes: attrs}) when is_map(attrs), do: attrs
  defp contact_additional(_contact), do: %{}

  defp link_company(_account, contact, company_id) when company_id in [nil, ""] do
    if contact.company_id do
      {:ok, unlinked} =
        Contacts.update_contact(contact, %{
          company_id: nil,
          additional_attributes: Map.delete(contact.additional_attributes || %{}, "company_name")
        })

      unlinked
    else
      contact
    end
  end

  defp link_company(account, contact, company_id) do
    company = Companies.get_company!(account, company_id)
    {:ok, linked} = Contacts.assign_company(contact, company)
    linked
  end

  defp flatten(%Contact{} = contact) do
    extra = contact_additional(contact)

    Map.merge(
      %{
        "name" => form_value(contact.name),
        "phone_number" => form_value(contact.phone_number),
        "email" => form_value(contact.email),
        "identifier" => form_value(contact.identifier),
        "location" => form_value(contact.location),
        "country_code" => form_value(contact.country_code),
        "blocked" => contact.blocked,
        "company_id" => company_form_value(contact.company_id),
        "custom_attributes_json" => Jason.encode!(contact.custom_attributes || %{})
      },
      additional_form_values(extra)
    )
  end

  defp additional_form_values(extra) do
    Map.merge(
      Map.new(["city", "country", "description"], &{&1, form_value(extra[&1])}),
      social_form_values(Map.get(extra, "social_profiles", %{}))
    )
  end

  defp social_form_values(social) do
    Map.new(~w(linkedin facebook instagram whatsapp telegram twitter github), fn key ->
      {"social_#{key}", form_value(social[key])}
    end)
  end

  defp form_value(nil), do: ""
  defp form_value(value), do: value

  defp company_form_value(nil), do: ""
  defp company_form_value(company_id), do: to_string(company_id)

  defp company_name(%Contact{} = contact), do: contact_additional(contact)["company_name"]

  defp location(%Contact{} = contact) do
    extra = contact_additional(contact)

    [extra["city"], extra["country"]]
    |> Enum.reject(&(is_nil(&1) or String.trim(&1) == ""))
    |> Enum.join(", ")
    |> case do
      "" -> nil
      loc -> loc
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen overflow-hidden bg-canvas">
      <AppShell.sidebar
        current_scope={@current_scope}
        account_name={@account && @account.name}
        active={:contacts}
      />

      <section :if={@live_action == :index} class="flex min-w-0 flex-1 flex-col">
        <!-- Header 1:1 Chatwoot ContactsListLayout / ContactHeader.vue -->
        <header class="sticky top-0 z-20 border-b border-line bg-surface/90 px-6 backdrop-blur-sm">
          <div class="mx-auto flex w-full max-w-5xl items-center justify-between gap-4 py-4">
            <div class="flex items-center gap-3 min-w-0">
              <h2 class="truncate text-xl font-bold tracking-tight text-ink">Contacts</h2>
              <span class="rounded-full bg-highlight px-2.5 py-0.5 text-xs font-semibold text-ink/70">
                {length(@contacts)}
              </span>
            </div>

            <div class="flex items-center gap-3">
              <!-- Search Input 1:1 -->
              <form id="contact-search" phx-change="search" phx-submit="noop" class="relative w-64">
                <.icon
                  name="hero-magnifying-glass"
                  class="pointer-events-none absolute left-3 top-2.5 size-4 text-ink/40"
                />
                <input
                  type="search"
                  name="q"
                  value={@search}
                  placeholder="Search contacts..."
                  phx-debounce="300"
                  class="h-9 w-full rounded-lg border border-line bg-canvas pl-9 pr-3 text-sm text-ink outline-none transition placeholder:text-ink/40 focus:border-brand focus:ring-1 focus:ring-brand"
                />
              </form>

              <!-- Botão Filtro estilo Chatwoot -->
              <button
                type="button"
                id="toggle-filter"
                phx-click="toggle-filter-drawer"
                class={[
                  "relative flex size-9 items-center justify-center rounded-lg border text-ink/70 transition hover:bg-highlight hover:text-ink",
                  if(@filter_company != "" or @filter_blocked != "" or @show_filter_drawer,
                    do: "border-brand bg-brand-soft text-brand-deep",
                    else: "border-line bg-surface"
                  )
                ]}
                title="Filters"
              >
                <.icon name="hero-funnel" class="size-4" />
                <span
                  :if={@filter_company != "" or @filter_blocked != ""}
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

              <!-- New Contact Button -->
              <button
                id="new-contact"
                phx-click="new"
                class="rounded-lg bg-brand px-3.5 py-2 text-xs font-semibold text-white shadow-sm transition hover:brightness-110"
              >
                New contact
              </button>
            </div>
          </div>
        </header>

        <!-- Painel / Drawer de Filtros Ativos (estilo Chatwoot ContactsFilter) -->
        <div
          :if={@show_filter_drawer}
          id="filter-drawer"
          class="border-b border-line bg-surface px-6 py-4 transition-all"
        >
          <div class="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4">
            <div class="flex flex-wrap items-center gap-3">
              <span class="text-xs font-bold uppercase tracking-wider text-ink/50">Filter by:</span>

              <!-- Filtro de Empresa -->
              <form
                id="filter-company-form"
                phx-change="apply-filters"
                class="flex items-center gap-2"
              >
                <input type="hidden" name="blocked" value={@filter_blocked} />
                <select
                  name="company"
                  class="h-8 rounded-lg border border-line bg-canvas px-2.5 text-xs text-ink outline-none focus:border-brand"
                >
                  <option value="">All companies</option>
                  <option
                    :for={{name, id} <- @company_options}
                    :if={id != ""}
                    value={id}
                    selected={@filter_company == id}
                  >
                    {name}
                  </option>
                </select>
              </form>

              <!-- Filtro de Bloqueados -->
              <form
                id="filter-blocked-form"
                phx-change="apply-filters"
                class="flex items-center gap-2"
              >
                <input type="hidden" name="company" value={@filter_company} />
                <select
                  name="blocked"
                  class="h-8 rounded-lg border border-line bg-canvas px-2.5 text-xs text-ink outline-none focus:border-brand"
                >
                  <option value="">All statuses</option>
                  <option value="false" selected={@filter_blocked == "false"}>Active</option>
                  <option value="true" selected={@filter_blocked == "true"}>Blocked</option>
                </select>
              </form>

              <!-- Reset de filtros -->
              <button
                :if={@filter_company != "" or @filter_blocked != ""}
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
                phx-value-sort="email"
                phx-value-order={@sort_order}
                class={[
                  "rounded px-2 py-1 transition",
                  @sort_by == "email" && "bg-brand-soft font-semibold text-brand-deep"
                ]}
              >
                Email
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
              <button
                type="button"
                phx-click="update-sort"
                phx-value-sort="last_activity_at"
                phx-value-order={@sort_order}
                class={[
                  "rounded px-2 py-1 transition",
                  @sort_by == "last_activity_at" && "bg-brand-soft font-semibold text-brand-deep"
                ]}
              >
                Activity
              </button>
            </div>
          </div>
        </div>

        <!-- Lista de Cards 1:1 estilo ContactsCard.vue -->
        <main class="flex-1 overflow-y-auto px-6 py-6">
          <div class="mx-auto w-full max-w-5xl">
            <div id="contacts" class="flex flex-col gap-3">
              <div class="hidden only:block rounded-xl border border-line bg-surface px-6 py-16 text-center">
                <span class="mx-auto flex size-12 items-center justify-center rounded-full bg-brand-soft text-brand">
                  <.icon name="hero-users" class="size-6" />
                </span>
                <h3 class="mt-3 text-sm font-semibold text-ink">No contacts found</h3>
                <p class="mt-1 text-xs text-ink/50">
                  Try adjusting your search or filters, or add a new contact.
                </p>
                <button
                  type="button"
                  phx-click="new"
                  class="mt-4 rounded-lg bg-brand px-4 py-2 text-xs font-semibold text-white shadow-sm hover:brightness-110"
                >
                  Create contact
                </button>
              </div>

              <!-- Card de Contato 1:1 -->
              <div
                :for={contact <- @contacts}
                id={"contact-#{contact.id}"}
                class="group rounded-xl border border-line bg-surface p-4 shadow-sm transition hover:border-brand/40 hover:shadow-md"
              >
                <div class="flex items-center justify-between gap-4">
                  <div class="flex min-w-0 flex-1 items-center gap-3.5">
                    <span class="flex size-11 shrink-0 items-center justify-center rounded-full bg-brand-soft text-sm font-bold text-brand-deep ring-1 ring-brand/10">
                      {AppShell.initials(contact.name || "?")}
                    </span>

                    <div class="min-w-0 flex-1">
                      <div class="flex flex-wrap items-center gap-x-2.5">
                        <span class="truncate text-sm font-bold text-ink">{contact.name}</span>
                        <span
                          :if={company_name(contact)}
                          class="inline-flex items-center gap-1 text-xs text-ink/60"
                        >
                          <.icon name="hero-building-office" class="size-3 text-ink/40" />
                          {company_name(contact)}
                        </span>
                        <span
                          :if={contact.blocked}
                          class="rounded-full bg-danger/10 px-2 py-0.5 text-[10px] font-semibold text-danger"
                        >
                          Blocked
                        </span>
                      </div>

                      <div class="mt-1 flex flex-wrap items-center gap-x-3 text-xs text-ink/60">
                        <span :if={contact.email} class="truncate">{contact.email}</span>
                        <span :if={contact.email && contact.phone_number} class="text-ink/20">•</span>
                        <span :if={contact.phone_number} class="truncate">{contact.phone_number}</span>
                        <span
                          :if={(contact.email || contact.phone_number) && location(contact)}
                          class="text-ink/20"
                        >•</span>
                        <span :if={location(contact)} class="truncate">{location(contact)}</span>
                        <span class="text-ink/20">•</span>
                        <.link
                          navigate={~p"/app/contacts/#{contact.id}"}
                          class="font-semibold text-brand hover:underline"
                        >
                          View details
                        </.link>
                      </div>
                    </div>
                  </div>

                  <button
                    phx-click="toggle-expand"
                    phx-value-id={contact.id}
                    aria-label="Expand"
                    class="rounded-lg p-2 text-ink/40 transition hover:bg-highlight hover:text-ink"
                  >
                    <.icon
                      name={
                        if(@expanded_id == to_string(contact.id),
                          do: "hero-chevron-up",
                          else: "hero-chevron-down"
                        )
                      }
                      class="size-4"
                    />
                  </button>
                </div>

                <!-- Expansão inline rápida (Quick Edit) -->
                <div
                  :if={@expanded_id == to_string(contact.id) && @quick_form}
                  class="mt-4 border-t border-line pt-4"
                >
                  <.form
                    for={@quick_form}
                    id={"quick-form-#{contact.id}"}
                    phx-change="quick-validate"
                    phx-submit="quick-save"
                    class="[&_.fieldset]:mb-0 [&_.label]:mb-0.5 [&_.label]:text-xs [&_.label]:font-medium [&_.label]:text-ink/70 [&_input]:h-8 [&_input]:text-xs [&_select]:h-8 [&_select]:text-xs"
                  >
                    <div class="grid grid-cols-1 gap-2.5 sm:grid-cols-3">
                      <.input field={@quick_form[:name]} type="text" label="Name" />
                      <.input field={@quick_form[:email]} type="email" label="Email" />
                      <.input field={@quick_form[:phone_number]} type="text" label="Phone" />
                      <.input
                        field={@quick_form[:company_id]}
                        type="select"
                        label="Company"
                        options={@company_options}
                      />
                      <.input field={@quick_form[:city]} type="text" label="City" />
                      <.input field={@quick_form[:country]} type="text" label="Country" />
                    </div>
                    <div class="mt-3 flex items-center justify-between border-t border-line pt-3">
                      <button
                        type="button"
                        phx-click="delete"
                        phx-value-id={contact.id}
                        data-confirm="Delete this contact?"
                        class="text-xs font-semibold text-danger hover:underline"
                      >
                        Delete contact
                      </button>
                      <button
                        type="submit"
                        class="rounded-lg bg-brand px-3.5 py-1.5 text-xs font-semibold text-white shadow-sm hover:brightness-110"
                      >
                        Save
                      </button>
                    </div>
                  </.form>
                </div>
              </div>
            </div>
          </div>
        </main>
      </section>

      <section
        :if={@live_action == :show && @contact}
        class="flex min-w-0 flex-1 overflow-hidden bg-canvas"
      >
        <!-- Layout principal (Centro: perfil e formulário com largura máxima estilo Chatwoot) -->
        <div class="flex min-w-0 flex-1 flex-col overflow-y-auto">
          <!-- Top bar / Header com Breadcrumbs e Botões de Ação estilo Chatwoot -->
          <header class="sticky top-0 z-10 border-b border-line bg-surface/90 px-6 py-4 backdrop-blur-sm">
            <div class="mx-auto flex max-w-2xl items-center justify-between gap-4">
              <nav class="flex items-center gap-2 text-sm text-ink/60">
                <.link
                  navigate={~p"/app/contacts"}
                  class="font-medium hover:text-brand hover:underline"
                >
                  Contacts
                </.link>
                <span class="text-ink/30">/</span>
                <span class="truncate font-semibold text-ink">{@contact.name}</span>
              </nav>

              <div class="flex items-center gap-2">
                <button
                  type="button"
                  phx-click="toggle-block"
                  class={[
                    "rounded-lg border px-3 py-1.5 text-xs font-semibold transition",
                    if(@contact.blocked,
                      do: "border-danger text-danger hover:bg-danger hover:text-white",
                      else: "border-line text-ink/80 hover:bg-highlight"
                    )
                  ]}
                >
                  {if @contact.blocked, do: "Unblock contact", else: "Block contact"}
                </button>

                <.link
                  :if={@contact_conversations != []}
                  navigate={~p"/app?conversation_id=#{List.first(@contact_conversations).id}"}
                  class="rounded-lg bg-brand px-3.5 py-1.5 text-xs font-semibold text-white shadow-sm hover:brightness-110"
                >
                  Send message
                </.link>
              </div>
            </div>
          </header>

          <main class="mx-auto w-full max-w-2xl px-6 py-8">
            <div id="contact-detail" class="flex flex-col items-start gap-8">
              <!-- Top Avatar & Name Info -->
              <div id="contact-profile" class="flex items-center gap-4">
                <span class="flex size-16 shrink-0 items-center justify-center rounded-full bg-brand-soft text-2xl font-bold text-brand ring-1 ring-brand/10">
                  {AppShell.initials(@contact.name || "?")}
                </span>
                <div class="min-w-0">
                  <h3 class="truncate text-xl font-bold text-ink">{@contact.name}</h3>
                  <div class="mt-1 flex flex-wrap items-center gap-x-2 text-xs text-ink/60">
                    <span
                      :if={@contact.identifier}
                      class="inline-flex items-center gap-1 font-mono text-ink/80"
                    >
                      <.icon name="hero-identification" class="size-3.5 text-ink/50" />
                      {@contact.identifier}
                    </span>
                    <span :if={@contact.identifier}>•</span>
                    <span>Created {Calendar.strftime(@contact.inserted_at, "%b %d, %Y")}</span>
                    <span>•</span>
                    <span>
                      {if @contact.last_activity_at,
                        do: "Active #{Calendar.strftime(@contact.last_activity_at, "%b %d, %H:%M")}",
                        else: "No activity yet"}
                    </span>
                  </div>
                </div>
              </div>

              <!-- Main Edit Form (ContactsForm.vue style) -->
              <div id="contact-information" class="w-full">
                <.form
                  for={@quick_form}
                  id={"quick-form-#{@contact.id}"}
                  phx-change="edit-details-validate"
                  phx-submit="edit-details-save"
                  class="flex flex-col gap-5 [&_.fieldset]:mb-0 [&_.label]:mb-0.5 [&_.label]:text-xs [&_.label]:font-medium [&_.label]:text-ink/70 [&_input]:h-9 [&_input]:text-sm [&_select]:h-9 [&_select]:text-sm"
                >
                  <div>
                    <h4 class="text-xs font-bold uppercase tracking-wider text-ink/50">
                      Contact Details
                    </h4>
                    <div class="mt-2.5 grid grid-cols-1 gap-x-4 gap-y-2 sm:grid-cols-2">
                      <.input
                        field={@quick_form[:name]}
                        type="text"
                        label="Full name"
                        placeholder="Full name"
                      />
                      <.input
                        field={@quick_form[:email]}
                        type="email"
                        label="Email address"
                        placeholder="Email address"
                      />
                      <.input
                        field={@quick_form[:phone_number]}
                        type="text"
                        label="Phone number"
                        placeholder="Phone number"
                      />
                      <.input
                        field={@quick_form[:company_id]}
                        type="select"
                        label="Company"
                        options={@company_options}
                      />
                      <.input field={@quick_form[:city]} type="text" label="City" placeholder="City" />
                      <.input
                        field={@quick_form[:country]}
                        type="text"
                        label="Country"
                        placeholder="Country"
                      />
                      <.input
                        field={@quick_form[:location]}
                        type="text"
                        label="Location"
                        placeholder="Location"
                      />
                      <.input
                        field={@quick_form[:country_code]}
                        type="text"
                        label="Country code"
                        placeholder="US, BR, etc."
                      />
                      <.input
                        field={@quick_form[:identifier]}
                        type="text"
                        label="Identifier"
                        placeholder="External ID"
                      />
                      <div class="sm:col-span-2">
                        <.input
                          field={@quick_form[:description]}
                          type="text"
                          label="Bio / description"
                          placeholder="Bio description..."
                        />
                      </div>
                    </div>
                  </div>

                  <div>
                    <h4 class="text-xs font-bold uppercase tracking-wider text-ink/50">
                      Social Media Profiles
                    </h4>
                    <div class="mt-2.5 grid grid-cols-1 gap-x-4 gap-y-2 sm:grid-cols-2">
                      <.input
                        field={@quick_form[:social_whatsapp]}
                        type="text"
                        label="WhatsApp"
                        placeholder="WhatsApp username/number"
                      />
                      <.input
                        field={@quick_form[:social_telegram]}
                        type="text"
                        label="Telegram"
                        placeholder="Telegram username"
                      />
                      <.input
                        field={@quick_form[:social_linkedin]}
                        type="text"
                        label="LinkedIn"
                        placeholder="LinkedIn profile URL"
                      />
                      <.input
                        field={@quick_form[:social_twitter]}
                        type="text"
                        label="X (Twitter)"
                        placeholder="Twitter handle"
                      />
                      <.input
                        field={@quick_form[:social_facebook]}
                        type="text"
                        label="Facebook"
                        placeholder="Facebook profile URL"
                      />
                      <.input
                        field={@quick_form[:social_instagram]}
                        type="text"
                        label="Instagram"
                        placeholder="Instagram handle"
                      />
                      <.input
                        field={@quick_form[:social_github]}
                        type="text"
                        label="GitHub"
                        placeholder="GitHub profile"
                      />
                    </div>
                  </div>

                  <div>
                    <h4 class="text-xs font-bold uppercase tracking-wider text-ink/50">
                      Custom Attributes
                    </h4>
                    <div class="mt-2">
                      <.input
                        field={@quick_form[:custom_attributes_json]}
                        type="textarea"
                        label="Attributes (JSON format)"
                        placeholder="{}"
                      />
                    </div>
                  </div>

                  <div class="flex items-center justify-between border-t border-line pt-3.5">
                    <.input field={@quick_form[:blocked]} type="checkbox" label="Block this contact" />
                    <button
                      type="submit"
                      class="rounded-lg bg-brand px-4 py-1.5 text-xs font-semibold text-white shadow-sm hover:brightness-110"
                    >
                      Update details
                    </button>
                  </div>
                </.form>
              </div>

              <!-- Delete Contact Section (Policy / Admin style) -->
              <div class="w-full border-t border-line pt-6">
                <div class="flex items-center justify-between">
                  <div>
                    <h5 class="text-sm font-semibold text-ink">Delete Contact</h5>
                    <p class="text-xs text-ink/60">
                      Permanently delete this contact and all related data.
                    </p>
                  </div>
                  <button
                    type="button"
                    phx-click="delete"
                    phx-value-id={@contact.id}
                    data-confirm="Are you sure you want to delete this contact? This action cannot be undone."
                    class="rounded-lg border border-danger/40 px-3.5 py-1.5 text-xs font-semibold text-danger hover:bg-danger hover:text-white"
                  >
                    Delete contact
                  </button>
                </div>
              </div>
            </div>
          </main>
        </div>

        <!-- Sidebar na Direita (estilo Chatwoot Desktop Sidebar com abas: History, Attributes, Inboxes) -->
        <aside
          id="contact-detail-sidebar"
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
                History ({length(@contact_conversations)})
              </button>
              <button
                type="button"
                phx-click="set-tab"
                phx-value-tab="inboxes"
                class={[
                  "flex-1 rounded-md py-1.5 text-xs font-medium transition",
                  if(@active_tab == "inboxes",
                    do: "bg-surface font-semibold text-ink shadow-sm",
                    else: "text-ink/60 hover:text-ink"
                  )
                ]}
              >
                Channels ({length(@contact_inboxes)})
              </button>
              <button
                type="button"
                phx-click="set-tab"
                phx-value-tab="attributes"
                class={[
                  "flex-1 rounded-md py-1.5 text-xs font-medium transition",
                  if(@active_tab == "attributes",
                    do: "bg-surface font-semibold text-ink shadow-sm",
                    else: "text-ink/60 hover:text-ink"
                  )
                ]}
              >
                Attributes
              </button>
            </div>
          </div>

          <!-- Conteúdo da Sidebar de acordo com a aba -->
          <div class="min-h-0 flex-1 overflow-y-auto p-4">
            <!-- Aba: Histórico de Conversas (ContactHistory.vue) -->
            <div :if={@active_tab == "history"} id="contact-conversations" class="space-y-3">
              <div :if={@contact_conversations == []} class="py-12 text-center text-sm text-ink/50">
                No conversations yet.
              </div>
              <div
                :for={conv <- @contact_conversations}
                id={"history-#{conv.id}"}
                class="group flex flex-col gap-2 rounded-xl border border-line p-3 transition hover:border-brand/40 hover:bg-canvas"
              >
                <div class="flex items-center justify-between">
                  <span class="inline-flex items-center gap-1.5 text-xs font-semibold text-ink">
                    <.icon name="hero-chat-bubble-left-right" class="size-3.5 text-brand" />
                    via {conv.contact_inbox.inbox.name}
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
                  <span>Conversation #{conv.id}</span>
                  <.link
                    navigate={~p"/app?conversation_id=#{conv.id}"}
                    class="font-semibold text-brand hover:underline"
                  >
                    Open →
                  </.link>
                </div>
              </div>
            </div>

            <!-- Aba: Inboxes / Channels -->
            <div :if={@active_tab == "inboxes"} id="contact-inboxes" class="space-y-3">
              <div :if={@contact_inboxes == []} class="py-12 text-center text-sm text-ink/50">
                No channel identities linked yet.
              </div>
              <div
                :for={identity <- @contact_inboxes}
                class="flex items-center justify-between rounded-xl border border-line p-3"
              >
                <div class="flex items-center gap-3">
                  <span class="flex size-8 items-center justify-center rounded-lg bg-brand-soft text-brand">
                    <.icon name="hero-chat-bubble-left-right" class="size-4" />
                  </span>
                  <div>
                    <p class="text-xs font-semibold text-ink">{identity.inbox.name}</p>
                    <p class="text-[11px] capitalize text-ink/50">{identity.inbox.channel_type}</p>
                  </div>
                </div>
                <span class="font-mono text-xs text-ink/60">{identity.source_id}</span>
              </div>
            </div>

            <!-- Aba: Custom Attributes Preview -->
            <div :if={@active_tab == "attributes"} class="space-y-3">
              <div
                :if={map_size(@contact.custom_attributes || %{}) == 0}
                class="py-12 text-center text-sm text-ink/50"
              >
                No custom attributes defined yet.
              </div>
              <div
                :for={{key, val} <- @contact.custom_attributes || %{}}
                class="flex flex-col gap-1 rounded-xl border border-line p-3 text-xs"
              >
                <span class="font-semibold text-ink/50 uppercase tracking-wider">{key}</span>
                <span class="break-words font-medium text-ink">{val}</span>
              </div>
            </div>
          </div>
        </aside>
      </section>

      <div
        :if={@modal_open}
        id="contact-modal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-ink/50 p-4"
      >
        <div class="w-full max-w-md rounded-2xl bg-surface p-6 shadow-xl">
          <h3 class="mb-4 text-base font-bold text-slate-900">New contact</h3>
          <.form for={@form} id="contact-form" phx-change="validate" phx-submit="save">
            <.input field={@form[:name]} type="text" label="Name" placeholder="Maria Silva" />
            <.input
              field={@form[:phone_number]}
              type="text"
              label="Phone"
              placeholder="+5511999990001"
            />
            <.input field={@form[:email]} type="email" label="Email" placeholder="maria@example.com" />
            <.input
              field={@form[:company_id]}
              type="select"
              label="Company"
              options={@company_options}
            />
            <div class="grid grid-cols-2 gap-3">
              <.input field={@form[:city]} type="text" label="City" />
              <.input field={@form[:country]} type="text" label="Country" />
            </div>
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
