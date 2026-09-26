defmodule ChatwooterWeb.ContactsLive do
  @moduledoc "Contatos estilo Chatwoot: cards expansíveis + página de detalhe."
  use ChatwooterWeb, :live_view

  alias Chatwooter.{Accounts, Companies, Contacts, Conversations}
  alias Chatwooter.Contacts.Contact
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
      |> assign(:search, "")
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
     |> assign(:contact_conversations, Conversations.list_contact_conversations(account, contact))}
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
    account |> Contacts.get_contact!(id) |> Contacts.delete_contact()

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

  defp load_contacts(%{assigns: %{account: account, search: q}} = socket) do
    contacts = Contacts.list_contacts(account)

    options =
      [{"No company", ""}] ++ Enum.map(Companies.list_companies(account), &{&1.name, &1.id})

    socket = assign(socket, :company_options, options)
    query = String.downcase(String.trim(q))

    filtered =
      if query == "" do
        contacts
      else
        Enum.filter(contacts, fn c ->
          String.contains?(String.downcase(c.name || ""), query) or
            String.contains?(String.downcase(c.phone_number || ""), query) or
            String.contains?(String.downcase(c.email || ""), query)
        end)
      end

    assign(socket, :contacts, filtered)
  end

  defp merge_extras(params, contact) do
    existing = contact_additional(contact)

    extras =
      %{
        "company_name" => params["company"],
        "city" => params["city"],
        "country" => params["country"]
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) or String.trim(v) == "" end)
      |> Map.new()

    dropped =
      ["company_name", "city", "country"]
      |> Enum.filter(fn key ->
        param_key = %{"company_name" => "company", "city" => "city", "country" => "country"}[key]

        Map.has_key?(params, param_key) and
          (is_nil(params[param_key]) or String.trim(params[param_key]) == "")
      end)

    additional = existing |> Map.merge(extras) |> Map.drop(dropped)

    params
    |> Map.drop(["company", "city", "country"])
    |> Map.put("additional_attributes", additional)
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

    %{
      "name" => contact.name || "",
      "phone_number" => contact.phone_number || "",
      "email" => contact.email || "",
      "company_id" => if(contact.company_id, do: to_string(contact.company_id), else: ""),
      "city" => extra["city"] || "",
      "country" => extra["country"] || ""
    }
  end

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
        <header class="flex items-center justify-between border-b border-slate-200 bg-surface px-6 py-4">
          <div>
            <h2 class="text-base font-bold text-slate-900">Contacts</h2>
            <p class="text-xs text-slate-500">{length(@contacts)} contacts</p>
          </div>
          <button
            id="new-contact"
            phx-click="new"
            class="rounded-lg bg-brand px-4 py-2 text-sm font-semibold text-white hover:brightness-110"
          >
            New contact
          </button>
        </header>

        <div class="border-b border-slate-200 bg-surface px-6 py-3">
          <form id="contact-search" phx-change="search" phx-submit="noop">
            <input
              type="text"
              name="q"
              value={@search}
              placeholder="Search by name, phone or email…"
              phx-debounce="300"
              class="w-full max-w-md rounded-lg border border-slate-300 px-3 py-2 text-sm"
            />
          </form>
        </div>

        <div class="flex-1 overflow-y-auto p-6">
          <div id="contacts" class="flex flex-col gap-4">
            <div class="hidden only:block rounded-xl border border-slate-200 bg-surface px-6 py-10 text-center text-sm text-slate-500">
              No contacts yet. Click “New contact” to add one.
            </div>
            <div
              :for={contact <- @contacts}
              id={"contact-#{contact.id}"}
              class="rounded-xl border border-slate-200 bg-surface px-5 py-4"
            >
              <div class="flex items-center gap-4">
                <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand/10 text-sm font-bold text-brand">
                  {AppShell.initials(contact.name || "?")}
                </span>
                <div class="min-w-0 flex-1">
                  <div class="flex flex-wrap items-center gap-x-3">
                    <span class="truncate text-base font-medium text-slate-900">{contact.name}</span>
                    <span :if={company_name(contact)} class="truncate text-sm text-slate-500">
                      {company_name(contact)}
                    </span>
                  </div>
                  <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
                    <span :if={contact.email} class="truncate text-sm text-slate-500">{contact.email}</span>
                    <span :if={contact.email && contact.phone_number} class="h-3 w-px bg-slate-300" />
                    <span :if={contact.phone_number} class="truncate text-sm text-slate-500">
                      {contact.phone_number}
                    </span>
                    <span :if={location(contact)} class="h-3 w-px bg-slate-300" />
                    <span :if={location(contact)} class="truncate text-sm text-slate-500">
                      {location(contact)}
                    </span>
                    <.link
                      navigate={~p"/app/contacts/#{contact.id}"}
                      class="text-xs font-semibold text-brand hover:underline"
                    >
                      View details
                    </.link>
                  </div>
                </div>
                <button
                  phx-click="toggle-expand"
                  phx-value-id={contact.id}
                  aria-label="Expand"
                  class="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
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

              <div
                :if={@expanded_id == to_string(contact.id) && @quick_form}
                class="mt-4 border-t border-slate-100 pt-4"
              >
                <.form
                  for={@quick_form}
                  id={"quick-form-#{contact.id}"}
                  phx-change="quick-validate"
                  phx-submit="quick-save"
                >
                  <div class="grid grid-cols-2 gap-3">
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
                  <div class="mt-3 flex items-center justify-between">
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
                      class="rounded-lg bg-brand px-4 py-2 text-sm font-semibold text-white hover:brightness-110"
                    >
                      Save
                    </button>
                  </div>
                </.form>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section
        :if={@live_action == :show && @contact}
        class="flex min-w-0 flex-1 flex-col overflow-y-auto"
      >
        <div class="border-b border-slate-200 bg-surface px-6 py-4">
          <.link navigate={~p"/app/contacts"} class="text-xs font-semibold text-brand hover:underline">
            ← Back to contacts
          </.link>
        </div>
        <div class="flex-1 space-y-4 p-6">
          <div id="contact-detail" class="rounded-xl border border-slate-200 bg-surface p-6">
            <div class="flex items-center gap-4">
              <span class="flex h-14 w-14 shrink-0 items-center justify-center rounded-full bg-brand/10 text-lg font-bold text-brand">
                {AppShell.initials(@contact.name || "?")}
              </span>
              <div class="min-w-0">
                <h2 class="truncate text-lg font-bold text-slate-900">{@contact.name}</h2>
                <p :if={company_name(@contact)} class="truncate text-sm text-slate-500">
                  {company_name(@contact)}
                </p>
              </div>
            </div>
            <dl class="mt-5 grid grid-cols-2 gap-4 text-sm">
              <div>
                <dt class="text-xs font-semibold uppercase tracking-wide text-slate-400">Email</dt>
                <dd class="mt-0.5 text-slate-900">{@contact.email || "—"}</dd>
              </div>
              <div>
                <dt class="text-xs font-semibold uppercase tracking-wide text-slate-400">Phone</dt>
                <dd class="mt-0.5 text-slate-900">{@contact.phone_number || "—"}</dd>
              </div>
              <div>
                <dt class="text-xs font-semibold uppercase tracking-wide text-slate-400">Location</dt>
                <dd class="mt-0.5 text-slate-900">{location(@contact) || "—"}</dd>
              </div>
              <div>
                <dt class="text-xs font-semibold uppercase tracking-wide text-slate-400">
                  Conversations
                </dt>
                <dd class="mt-0.5 text-slate-900">{length(@contact_conversations)}</dd>
              </div>
            </dl>
            <div
              :if={@expanded_id == to_string(@contact.id) && @quick_form}
              class="mt-5 border-t border-slate-100 pt-4"
            >
              <.form
                for={@quick_form}
                id={"quick-form-#{@contact.id}"}
                phx-change="quick-validate"
                phx-submit="quick-save"
              >
                <div class="grid grid-cols-2 gap-3">
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
                <div class="mt-3 flex justify-end">
                  <button
                    type="submit"
                    class="rounded-lg bg-brand px-4 py-2 text-sm font-semibold text-white hover:brightness-110"
                  >
                    Save
                  </button>
                </div>
              </.form>
            </div>
            <div class="mt-5 flex gap-3">
              <button
                phx-click="toggle-expand"
                phx-value-id={@contact.id}
                class="rounded-lg border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-600"
              >
                {if @expanded_id == to_string(@contact.id), do: "Close", else: "Edit"}
              </button>
              <button
                phx-click="delete"
                phx-value-id={@contact.id}
                data-confirm="Delete this contact?"
                class="rounded-lg border border-danger px-4 py-2 text-sm font-semibold text-danger hover:bg-danger hover:text-white"
              >
                Delete
              </button>
            </div>
          </div>

          <div class="rounded-xl border border-slate-200 bg-surface p-6">
            <h3 class="mb-3 text-sm font-bold text-slate-900">Conversations</h3>
            <div :if={@contact_conversations == []} class="text-sm text-slate-500">
              No conversations yet.
            </div>
            <div
              :for={conv <- @contact_conversations}
              id={"history-#{conv.id}"}
              class="flex items-center justify-between gap-3 border-b border-slate-100 py-2.5 last:border-0"
            >
              <div class="min-w-0">
                <p class="truncate text-sm font-semibold text-slate-900">
                  via {conv.contact_inbox.inbox.name}
                </p>
                <p class="text-xs capitalize text-slate-500">{conv.status}</p>
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
