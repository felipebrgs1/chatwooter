defmodule ChatwooterWeb.ContactsLive.Show do
  @moduledoc """
  Detalhe do contato — port de `routes/dashboard/contacts/pages/ContactManageView.vue`,
  `components-next/Contacts/ContactsDetailsLayout.vue`, `Pages/ContactDetails.vue`,
  `ContactsForm/ContactsForm.vue`, `ContactLabels/` e das abas de `ContactsSidebar/`.
  """
  use ChatwooterWeb, :live_view

  alias Chatwooter.{Accounts, Companies, Contacts, Conversations}
  alias Chatwooter.Contacts.Contact
  alias Chatwooter.Platform.{ContactMerge, RecordDeletion}
  alias ChatwooterWeb.Components.Contacts.ContactForm
  alias ChatwooterWeb.Countries

  @tabs [
    %{value: "attributes", label: "Attributes"},
    %{value: "history", label: "History"},
    %{value: "notes", label: "Notes"},
    %{value: "media", label: "Media"},
    %{value: "merge", label: "Merge"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    account = socket.assigns.current_scope.user |> Accounts.list_user_accounts() |> List.first()

    {:ok,
     socket
     |> assign(:account, account)
     |> assign(:tabs, @tabs)
     |> assign(:active_tab, "attributes")
     |> assign(:merge_primary_id, nil)
     |> assign(:merge_error, nil)
     |> assign(:country_options, Enum.map(Countries.all(), &%{value: &1.id, label: &1.name}))}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    contact = Contacts.get_contact!(socket.assigns.account, id)
    {:noreply, socket |> assign(:merge_primary_id, nil) |> load_contact(contact)}
  end

  defp load_contact(%{assigns: %{account: account}} = socket, contact) do
    socket
    |> assign(:contact, contact)
    |> assign(:page_title, contact.name)
    |> assign(:form_params, form_params(contact))
    |> assign_form()
    |> assign(:contact_labels, Contacts.list_contact_labels(contact))
    |> assign(:account_labels, Contacts.list_labels(account))
    |> assign(:companies, Companies.list_companies(account))
    |> assign(:attribute_definitions, Contacts.list_contact_attribute_definitions(account))
    |> assign(:notes, Contacts.list_contact_notes(account, contact))
    |> assign(:conversations, Conversations.list_contact_conversations(account, contact))
    |> assign(:attachments, Conversations.list_contact_attachments(account, contact))
    |> assign(
      :merge_candidates,
      account |> Contacts.list_contacts() |> Enum.reject(&(&1.id == contact.id))
    )
  end

  # ── formulário (ContactsForm.vue) ────────────────────────────────────────

  defp form_params(%Contact{} = contact) do
    extra = contact.additional_attributes || %{}
    social = extra["social_profiles"] || %{}
    [first | rest] = String.split(contact.name || "", " ")
    {phone_country, phone_local} = Countries.split_phone(contact.phone_number)

    %{
      "first_name" => first,
      "last_name" => Enum.join(rest, " "),
      "email" => contact.email,
      "phone_country" => phone_country && phone_country.id,
      "phone_local" => phone_local,
      "city" => extra["city"],
      "country_code" => extra["country_code"],
      "description" => extra["description"],
      "company_id" => contact.company_id && to_string(contact.company_id),
      "social" => Map.new(ContactForm.social_keys(), &{&1, social[&1] || ""})
    }
    |> Map.new(fn {key, value} -> {key, value || ""} end)
  end

  defp assign_form(socket, changeset \\ nil) do
    form =
      if changeset,
        do: to_form(changeset, as: "contact", action: :validate),
        else: to_form(socket.assigns.form_params, as: "contact")

    assign(socket, :form, form)
  end

  defp contact_attrs(params, %Contact{} = contact) do
    country = Countries.get(params["country_code"])
    phone_country = Countries.get(params["phone_country"])
    local = String.replace(params["phone_local"] || "", ~r/[^\d]/, "")

    social =
      params
      |> Map.get("social", %{})
      |> Enum.reject(fn {_key, value} -> String.trim(value || "") == "" end)
      |> Map.new()

    additional =
      (contact.additional_attributes || %{})
      |> Map.merge(%{
        "city" => blank_to_nil(params["city"]),
        "country_code" => country && country.id,
        "country" => country && country.name,
        "description" => blank_to_nil(params["description"]),
        "social_profiles" => social
      })
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    %{
      "name" => String.trim("#{params["first_name"]} #{params["last_name"]}"),
      "email" => blank_to_nil(params["email"]),
      "phone_number" =>
        if(local == "",
          do: nil,
          else: "#{(phone_country && phone_country.dial_code) || "+"}#{local}"
        ),
      "additional_attributes" => additional
    }
  end

  defp blank_to_nil(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: value)

  defp blank_to_nil(value), do: value

  @impl true
  def handle_event("validate", %{"contact" => params}, socket) do
    {:noreply,
     socket
     |> assign(:form_params, Map.merge(socket.assigns.form_params, params))
     |> assign_form()}
  end

  def handle_event("save", params, %{assigns: %{contact: contact, account: account}} = socket) do
    params = Map.merge(socket.assigns.form_params, Map.get(params, "contact", %{}))

    with {:ok, updated} <- Contacts.update_contact(contact, contact_attrs(params, contact)),
         {:ok, updated} <- link_company(account, updated, params["company_id"]) do
      {:noreply,
       socket
       |> load_contact(updated)
       |> put_flash(:info, "Contact updated successfully")}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:form_params, params)
         |> assign_form(%{changeset | params: params})
         |> put_flash(:error, "Unable to update contact. Please try again later.")}
    end
  end

  def handle_event("select-country", %{"value" => code}, socket),
    do: {:noreply, put_form_param(socket, "country_code", code)}

  def handle_event("select-phone-country", %{"value" => code}, socket),
    do: {:noreply, put_form_param(socket, "phone_country", code)}

  def handle_event("select-company", %{"value" => id}, socket),
    do: {:noreply, put_form_param(socket, "company_id", to_string(id))}

  # ── cabeçalho ───────────────────────────────────────────────────────────

  def handle_event("toggle-block", _params, %{assigns: %{contact: contact}} = socket) do
    blocked = !contact.blocked

    case Contacts.update_contact(contact, %{blocked: blocked}) do
      {:ok, updated} ->
        message =
          if blocked,
            do: "This contact is blocked successfully",
            else: "This contact is unblocked successfully"

        {:noreply, socket |> assign(:contact, updated) |> put_flash(:info, message)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to block contact. Please try again later.")}
    end
  end

  def handle_event("delete", _params, %{assigns: %{account: account, contact: contact}} = socket) do
    case RecordDeletion.delete_contact(account, contact.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Contact deleted successfully")
         |> push_navigate(to: ~p"/app/contacts")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete contact. Please try again later.")}
    end
  end

  # ── etiquetas (ContactLabels.vue) ───────────────────────────────────────

  def handle_event("add-label", %{"value" => title}, socket) do
    {:ok, labels} = Contacts.add_contact_label(socket.assigns.contact, title)
    {:noreply, assign(socket, :contact_labels, labels)}
  end

  def handle_event("remove-label", %{"title" => title}, socket) do
    {:ok, labels} = Contacts.remove_contact_label(socket.assigns.contact, title)
    {:noreply, assign(socket, :contact_labels, labels)}
  end

  # ── abas ────────────────────────────────────────────────────────────────

  def handle_event("set-tab", %{"tab" => tab}, socket) do
    if Enum.any?(@tabs, &(&1.value == tab)),
      do: {:noreply, assign(socket, :active_tab, tab)},
      else: {:noreply, socket}
  end

  def handle_event("save-attribute", %{"key" => key, "attribute" => %{"value" => value}}, socket) do
    update_attribute(socket, Contacts.put_custom_attribute(socket.assigns.contact, key, value))
  end

  def handle_event("select-attribute", %{"value" => value}, socket) do
    [key, option] = String.split(value, ":", parts: 2)
    update_attribute(socket, Contacts.put_custom_attribute(socket.assigns.contact, key, option))
  end

  def handle_event("toggle-attribute", %{"key" => key}, socket) do
    current = (socket.assigns.contact.custom_attributes || %{})[key] == true
    update_attribute(socket, Contacts.put_custom_attribute(socket.assigns.contact, key, !current))
  end

  def handle_event("delete-attribute", %{"key" => key}, socket) do
    case Contacts.delete_custom_attribute(socket.assigns.contact, key) do
      {:ok, contact} ->
        {:noreply,
         socket |> assign(:contact, contact) |> put_flash(:info, "Attribute deleted successfully")}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "Unable to delete attribute. Please try again later")}
    end
  end

  def handle_event("add-note", %{"note" => %{"content" => content}}, socket) do
    %{account: account, contact: contact, current_scope: %{user: user}} = socket.assigns

    case Contacts.create_note(account, contact, user, content) do
      {:ok, _note} ->
        {:noreply, assign(socket, :notes, Contacts.list_contact_notes(account, contact))}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_event("delete-note", %{"id" => id}, socket) do
    %{account: account, contact: contact} = socket.assigns
    {:ok, _} = Contacts.delete_note(account, id)
    {:noreply, assign(socket, :notes, Contacts.list_contact_notes(account, contact))}
  end

  def handle_event("select-merge-primary", %{"value" => id}, socket) do
    {:noreply, socket |> assign(:merge_primary_id, to_string(id)) |> assign(:merge_error, nil)}
  end

  def handle_event("merge-cancel", _params, socket) do
    {:noreply, socket |> assign(:merge_primary_id, nil) |> assign(:merge_error, nil)}
  end

  def handle_event("merge", _params, %{assigns: %{merge_primary_id: nil}} = socket) do
    {:noreply,
     assign(socket, :merge_error, "Please select a contact to merge with before proceeding")}
  end

  def handle_event("merge", _params, socket) do
    %{account: account, contact: contact, merge_primary_id: primary_id} = socket.assigns
    primary = Contacts.get_contact!(account, primary_id)

    case ContactMerge.merge(account, primary, contact) do
      {:ok, merged} ->
        {:noreply,
         socket
         |> put_flash(:info, "Contact merged successfully")
         |> push_navigate(to: ~p"/app/contacts/#{merged.id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not merge contacts, try again!")}
    end
  end

  defp update_attribute(socket, result) do
    case result do
      {:ok, contact} ->
        {:noreply,
         socket |> assign(:contact, contact) |> put_flash(:info, "Attribute updated successfully")}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "Unable to update attribute. Please try again later")}
    end
  end

  defp put_form_param(socket, key, value) do
    socket
    |> assign(:form_params, Map.put(socket.assigns.form_params, key, value))
    |> assign_form()
  end

  defp link_company(_account, %Contact{company_id: nil} = contact, id) when id in [nil, ""],
    do: {:ok, contact}

  defp link_company(_account, contact, id) when id in [nil, ""] do
    Contacts.update_contact(contact, %{
      company_id: nil,
      additional_attributes: Map.delete(contact.additional_attributes || %{}, "company_name")
    })
  end

  defp link_company(account, contact, id) do
    Contacts.assign_company(contact, Companies.get_company!(account, id))
  end
end
