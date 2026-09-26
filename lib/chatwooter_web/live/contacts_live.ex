defmodule ChatwooterWeb.ContactsLive do
  @moduledoc "CRM mínimo estilo Chatwoot: cadastro de contatos com telefone/email."
  use ChatwooterWeb, :live_view

  alias Chatwooter.{Accounts, Contacts}
  alias Chatwooter.Contacts.Contact
  alias ChatwooterWeb.AppShell

  @impl true
  def mount(_params, _session, socket) do
    account = Accounts.list_user_accounts(socket.assigns.current_scope.user) |> List.first()

    socket =
      socket
      |> assign(:account, account)
      |> assign(:contacts, [])
      |> assign(:search, "")
      |> assign(:editing, nil)
      |> assign(:modal_open, false)
      |> assign(:form, to_form(Contacts.change_contact(%Contact{}), as: "contact"))

    {:ok, if(account, do: load_contacts(socket), else: socket)}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:search, q) |> load_contacts()}
  end

  def handle_event("new", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing, nil)
     |> assign(:modal_open, true)
     |> assign(:form, to_form(Contacts.change_contact(%Contact{}), as: "contact"))}
  end

  def handle_event("edit", %{"id" => id}, %{assigns: %{account: account}} = socket) do
    contact = Contacts.get_contact!(account, id)

    {:noreply,
     socket
     |> assign(:editing, contact)
     |> assign(:modal_open, true)
     |> assign(:form, to_form(Contacts.change_contact(contact), as: "contact"))}
  end

  def handle_event("validate", %{"contact" => params}, socket) do
    contact = socket.assigns.editing || %Contact{}

    {:noreply,
     assign(
       socket,
       :form,
       to_form(Contacts.change_contact(contact, params), as: "contact", action: :validate)
     )}
  end

  def handle_event("save", %{"contact" => params}, %{assigns: %{account: account}} = socket) do
    case socket.assigns.editing do
      nil -> Contacts.create_contact(account, params)
      contact -> Contacts.update_contact(contact, params)
    end
    |> case do
      {:ok, _contact} ->
        {:noreply,
         socket
         |> assign(:editing, nil)
         |> assign(:modal_open, false)
         |> assign(:form, to_form(Contacts.change_contact(%Contact{}), as: "contact"))
         |> load_contacts()
         |> put_flash(:info, "Contact saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "contact", action: :validate))}
    end
  end

  def handle_event("delete", %{"id" => id}, %{assigns: %{account: account}} = socket) do
    account |> Contacts.get_contact!(id) |> Contacts.delete_contact()

    {:noreply, socket |> load_contacts() |> put_flash(:info, "Contact deleted.")}
  end

  def handle_event("close-modal", _params, socket) do
    {:noreply, assign(socket, :modal_open, false)}
  end

  defp load_contacts(%{assigns: %{account: account, search: q}} = socket) do
    contacts = Contacts.list_contacts(account)
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen overflow-hidden bg-canvas">
      <AppShell.sidebar
        current_scope={@current_scope}
        account_name={@account && @account.name}
        active={:contacts}
      />

      <section class="flex min-w-0 flex-1 flex-col">
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
          <div id="contacts" class="overflow-hidden rounded-xl border border-slate-200 bg-surface">
            <div class="hidden only:block px-6 py-10 text-center text-sm text-slate-500">
              No contacts yet. Click “New contact” to add one.
            </div>
            <div
              :for={contact <- @contacts}
              id={"contact-#{contact.id}"}
              class="flex items-center gap-4 border-b border-slate-100 px-6 py-3 last:border-0 hover:bg-slate-50"
            >
              <span class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand/10 text-xs font-bold text-brand">
                {AppShell.initials(contact.name || "?")}
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-semibold text-slate-900">{contact.name}</p>
                <p class="truncate text-xs text-slate-500">
                  {contact.phone_number || "—"} · {contact.email || "no email"}
                </p>
              </div>
              <button
                phx-click="edit"
                phx-value-id={contact.id}
                class="text-xs font-semibold text-brand hover:underline"
              >
                Edit
              </button>
              <button
                phx-click="delete"
                phx-value-id={contact.id}
                data-confirm="Delete this contact?"
                class="text-xs font-semibold text-danger hover:underline"
              >
                Delete
              </button>
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
          <h3 class="mb-4 text-base font-bold text-slate-900">
            {if @editing, do: "Edit contact", else: "New contact"}
          </h3>
          <.form for={@form} id="contact-form" phx-change="validate" phx-submit="save">
            <.input field={@form[:name]} type="text" label="Name" placeholder="Maria Silva" />
            <.input
              field={@form[:phone_number]}
              type="text"
              label="Phone"
              placeholder="+5511999990001"
            />
            <.input field={@form[:email]} type="email" label="Email" placeholder="maria@example.com" />
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
