defmodule ChatwooterWeb.ContactsLive.Index do
  @moduledoc "Lista de contatos estilo Chatwoot (cards expansíveis). O detalhe fica em `ContactsLive.Show`."
  use ChatwooterWeb, :live_view

  alias Chatwooter.Accounts
  alias Chatwooter.Companies
  alias Chatwooter.Contacts
  alias Chatwooter.Contacts.Contact
  alias Chatwooter.Platform.RecordDeletion

  @impl true
  def mount(_params, _session, socket) do
    account = Accounts.list_user_accounts(socket.assigns.current_scope.user) |> List.first()

    socket =
      socket
      |> assign(:account, account)
      |> assign(:contacts, [])
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
  def handle_params(_params, _uri, %{assigns: %{account: account}} = socket)
      when not is_nil(account) do
    {:noreply,
     socket
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
        link_company(account, contact, company_id)

        {:noreply,
         socket
         |> assign(:expanded_id, nil)
         |> assign(:quick_form, nil)
         |> load_contacts()
         |> put_flash(:info, "Contact updated.")}

      {:error, changeset} ->
        {:noreply,
         assign(socket, :quick_form, to_form(changeset, as: "contact", action: :validate))}
    end
  end

  def handle_event("delete", %{"id" => id}, %{assigns: %{account: account}} = socket) do
    RecordDeletion.delete_contact(account, id)

    {:noreply, socket |> load_contacts() |> put_flash(:info, "Contact deleted.")}
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
end
