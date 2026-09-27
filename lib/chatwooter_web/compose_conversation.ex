defmodule ChatwooterWeb.ComposeConversation do
  @moduledoc """
  Estado e eventos do popover "nova conversa" — port de
  `chatwoot/app/javascript/dashboard/components-next/NewConversation/ComposeConversation.vue`
  (+ o estado de `ComposeNewConversationForm.vue` e `helpers/composeConversationHelper.js`).

  Anexado pelo `ChatwooterWeb.Sidebar` a todo LiveView do dashboard: o estado fica em
  `@sidebar.compose` (a sidebar abre o popover; a página do contato também, já com o
  contato escolhido). Eventos `compose:*`. A renderização fica em
  `ChatwooterWeb.Components.NewConversation.ComposeConversation`.
  """
  use ChatwooterWeb, :verified_routes

  import Phoenix.Component, only: [update: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, put_flash: 3, push_navigate: 2, push_patch: 2]

  alias Chatwooter.Contacts
  alias Chatwooter.Platform.ComposeConversation, as: Compose

  # composeConversationHelper.js: MIN_SEARCH_LENGTH
  @min_search_length 2
  @email ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/
  @phone ~r/^\+[1-9]\d{6,14}$/

  @doc "Estado inicial (popover fechado)."
  def initial do
    %{
      anchor: nil,
      contact_locked?: false,
      query: "",
      contacts: [],
      show_contacts_dropdown: false,
      contact: nil,
      contactable_inboxes: [],
      show_inboxes_dropdown: false,
      target: nil,
      message: "",
      errors: %{}
    }
  end

  @doc "Coloca o estado em `@sidebar.compose` e trata os eventos `compose:*`."
  def attach(socket) do
    socket
    |> update(:sidebar, &Map.put(&1, :compose, initial()))
    |> attach_hook(:compose_events, :handle_event, &handle_event/3)
  end

  @doc "Rótulo do contato (`selectedContactLabel` do `ContactSelector.vue`)."
  def contact_label(%{name: name, email: email}) when email not in [nil, ""],
    do: "#{name} (#{email})"

  def contact_label(%{name: name, phone_number: phone}) when phone not in [nil, ""],
    do: "#{name} (#{phone})"

  def contact_label(%{name: name}), do: name

  @doc "Rótulo do item na lista de contatos (`contactsList` do `ContactSelector.vue`)."
  def contact_option_label(%{name: name, email: email}) when email not in [nil, ""],
    do: "#{name} (#{email})"

  def contact_option_label(%{name: name}), do: name

  @doc "WhatsApp só abre conversa por template (a janela de 24h está fechada)."
  def whatsapp?(%{target: %{inbox: %{channel_type: :whatsapp}}}), do: true
  def whatsapp?(_compose), do: false

  @doc "`showNoInboxAlert`: contato escolhido sem nenhuma inbox contactável."
  def no_inbox?(%{contact: contact, contactable_inboxes: inboxes}),
    do: contact != nil and inboxes == []

  @doc """
  Sugestão "criar contato" do `TagInput` (`buildTagMenuItems`): só quando nada foi
  encontrado e o texto é um email válido (ou telefone, se começa com "+").
  """
  def create_suggestion(%{query: query, contacts: []}) do
    value = String.trim(query)
    if value != "" and valid_new_contact?(value), do: value
  end

  def create_suggestion(_compose), do: nil

  @doc "Texto inválido para o tipo do input (`isNewTagInValidType`), pintado de vermelho."
  def invalid_query?(%{query: query}) do
    value = String.trim(query)
    value != "" and not valid_new_contact?(value)
  end

  @doc "Tipo do input: `tel` quando começa com \"+\", senão `email` (`handleInput`)."
  def input_type(%{query: "+" <> _}), do: "tel"
  def input_type(_compose), do: "email"

  defp valid_new_contact?("+" <> _ = value), do: Regex.match?(@phone, value)
  defp valid_new_contact?(value), do: Regex.match?(@email, value)

  defp handle_event("compose:toggle", %{"anchor" => anchor} = params, socket) do
    if compose(socket).anchor == anchor do
      {:halt, close(socket)}
    else
      {:halt, open(socket, anchor, params["contact_id"])}
    end
  end

  defp handle_event("compose:close", _params, socket), do: {:halt, close(socket)}

  defp handle_event("compose:discard", _params, socket) do
    {:halt, socket |> put_compose(&%{&1 | message: ""}) |> close()}
  end

  defp handle_event("compose:search", %{"q" => query}, socket) do
    trimmed = String.trim(query)

    contacts =
      if String.length(trimmed) >= @min_search_length, do: search(socket, trimmed), else: []

    {:halt,
     put_compose(
       socket,
       &%{
         &1
         | query: query,
           contacts: contacts,
           show_contacts_dropdown: String.length(trimmed) > 1
       }
     )}
  end

  # Enter no TagInput (`addTag`): contato com esse email, senão cria um novo.
  defp handle_event("compose:add_contact", %{"q" => query}, socket) do
    value = String.trim(query)
    compose = compose(socket)

    cond do
      not valid_new_contact?(value) ->
        {:halt, socket}

      contact = Enum.find(compose.contacts, &(&1.email == value)) ->
        {:halt, select_contact(socket, contact)}

      true ->
        {:halt, create_contact(socket, value)}
    end
  end

  defp handle_event("compose:select_contact", %{"id" => id}, socket) do
    case Enum.find(compose(socket).contacts, &(to_string(&1.id) == to_string(id))) do
      nil -> {:halt, socket}
      contact -> {:halt, select_contact(socket, contact)}
    end
  end

  defp handle_event("compose:create_contact", _params, socket) do
    case create_suggestion(compose(socket)) do
      nil -> {:halt, socket}
      value -> {:halt, create_contact(socket, value)}
    end
  end

  defp handle_event("compose:clear_contact", _params, socket) do
    {:halt,
     put_compose(
       socket,
       &%{
         &1
         | contact: nil,
           contactable_inboxes: [],
           target: nil,
           message: "",
           query: "",
           show_inboxes_dropdown: false
       }
     )}
  end

  defp handle_event("compose:close_contacts", _params, socket) do
    {:halt, put_compose(socket, &%{&1 | show_contacts_dropdown: false})}
  end

  defp handle_event("compose:toggle_inboxes", _params, socket) do
    {:halt, put_compose(socket, &%{&1 | show_inboxes_dropdown: !&1.show_inboxes_dropdown})}
  end

  defp handle_event("compose:close_inboxes", _params, socket) do
    {:halt, put_compose(socket, &%{&1 | show_inboxes_dropdown: false})}
  end

  defp handle_event("compose:select_inbox", %{"id" => id}, socket) do
    target =
      Enum.find(compose(socket).contactable_inboxes, &(to_string(&1.inbox.id) == to_string(id)))

    {:halt,
     put_compose(socket, &%{&1 | target: target, show_inboxes_dropdown: false, errors: %{}})}
  end

  defp handle_event("compose:clear_inbox", _params, socket) do
    {:halt, put_compose(socket, &%{&1 | target: nil, errors: %{}})}
  end

  defp handle_event("compose:change", %{"message" => message}, socket) do
    {:halt, put_compose(socket, &%{&1 | message: message})}
  end

  defp handle_event("compose:send", params, socket) do
    socket = put_compose(socket, &%{&1 | message: params["message"] || &1.message})
    compose = compose(socket)

    errors =
      %{
        contact: compose.contact == nil,
        inbox: compose.target == nil,
        # No WhatsApp o texto livre nem aparece: o envio seria por template.
        message: String.trim(compose.message) == ""
      }
      |> Map.filter(fn {_field, invalid?} -> invalid? end)

    if errors == %{} do
      {:halt, create_conversation(socket, compose)}
    else
      {:halt, put_compose(socket, &%{&1 | errors: errors})}
    end
  end

  defp handle_event(_event, _params, socket), do: {:cont, socket}

  defp compose(socket), do: socket.assigns.sidebar.compose

  defp put_compose(socket, fun), do: update(socket, :sidebar, &Map.update!(&1, :compose, fun))

  defp account(socket), do: socket.assigns.sidebar.account

  # createContactSearcher: só contatos alcançáveis (com telefone ou email).
  defp search(socket, query) do
    socket
    |> account()
    |> Contacts.search_contacts(query)
    |> Enum.filter(&(present?(&1.phone_number) or present?(&1.email)))
    |> Enum.sort_by(&String.downcase(&1.name || ""))
  end

  defp present?(value), do: value not in [nil, ""]

  defp open(socket, anchor, nil) do
    socket
    |> put_compose(fn compose ->
      # Veio da página do contato? A sidebar abre sem contato pré-escolhido.
      base = if compose.contact_locked?, do: initial(), else: reset_selection(compose)
      %{base | anchor: anchor}
    end)
  end

  defp open(socket, anchor, contact_id) do
    contact = Contacts.get_contact!(account(socket), contact_id)
    locked = compose(socket).contact_locked? && compose(socket).contact

    socket
    |> put_compose(fn compose ->
      base = if locked && locked.id == contact.id, do: compose, else: initial()
      %{base | anchor: anchor, contact_locked?: true}
    end)
    |> select_contact(contact, open_inboxes?: false)
  end

  # closeCompose: a mensagem digitada sobrevive; contato (se não travado) e inbox não.
  defp close(socket) do
    put_compose(socket, fn compose ->
      compose = %{reset_selection(compose) | anchor: nil}
      if compose.contact_locked?, do: compose, else: %{compose | contact: nil}
    end)
  end

  defp reset_selection(compose) do
    %{
      compose
      | target: nil,
        contacts: [],
        query: "",
        show_contacts_dropdown: false,
        show_inboxes_dropdown: false,
        errors: %{}
    }
  end

  defp select_contact(socket, contact, opts \\ []) do
    inboxes = Contacts.list_contactable_inboxes(account(socket), contact)

    put_compose(
      socket,
      &%{
        &1
        | contact: contact,
          contactable_inboxes: inboxes,
          contacts: [],
          query: "",
          show_contacts_dropdown: false,
          show_inboxes_dropdown: Keyword.get(opts, :open_inboxes?, true),
          errors: %{}
      }
    )
  end

  # createNewContact: nome = parte antes do "@" capitalizada, ou o telefone sem "+".
  defp create_contact(socket, value) do
    attrs =
      case value do
        "+" <> number ->
          %{name: number, phone_number: value}

        email ->
          %{name: email |> String.split("@") |> hd() |> String.capitalize(), email: email}
      end

    case Contacts.create_contact(account(socket), attrs) do
      {:ok, contact} ->
        select_contact(socket, contact)

      {:error, changeset} ->
        put_flash(socket, :error, changeset_message(changeset))
    end
  end

  defp changeset_message(%Ecto.Changeset{errors: [{field, {message, _opts}} | _]}) do
    field = field |> to_string() |> String.replace("_", " ") |> String.capitalize()
    "#{field} #{message}"
  end

  defp changeset_message(_changeset), do: "We couldn’t create the contact. Please try again."

  defp create_conversation(socket, compose) do
    %{inbox: inbox, source_id: source_id} = compose.target

    case Compose.create(account(socket), %{
           user: socket.assigns.current_scope.user,
           contact: compose.contact,
           inbox: inbox,
           source_id: source_id,
           content: compose.message
         }) do
      {:ok, conversation} ->
        # O Chatwoot mostra um alerta com link "View"; aqui já abrimos a conversa.
        socket
        |> put_compose(fn _compose -> initial() end)
        |> put_flash(:info, "The message was sent successfully!")
        |> go_to(~p"/app?conversation_id=#{conversation.id}")

      {:error, _reason} ->
        put_flash(
          socket,
          :error,
          "An error occurred while creating the conversation. Please try again later."
        )
    end
  end

  defp go_to(socket, to) do
    case socket.assigns.sidebar.uri do
      %URI{path: "/app"} -> push_patch(socket, to: to)
      _uri -> push_navigate(socket, to: to)
    end
  end
end
