defmodule ChatwooterWeb.CompaniesLive.Show do
  @moduledoc "Detalhe da empresa estilo Chatwoot (`CompanyDetailView.vue`): perfil, contatos e atributos."
  use ChatwooterWeb, :live_view

  alias Chatwooter.{Accounts, Companies, Conversations}
  alias ChatwooterWeb.CompaniesLive.FormModal

  on_mount FormModal

  @impl true
  def mount(_params, _session, socket) do
    account = Accounts.list_user_accounts(socket.assigns.current_scope.user) |> List.first()

    {:ok,
     socket
     |> assign(:account, account)
     |> assign(:active_tab, "contacts")
     |> assign(:custom_form, to_form(%{"key" => "", "value" => ""}, as: "custom"))}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    company = Companies.get_company!(socket.assigns.account, id)

    {:noreply,
     socket
     |> assign(:active_tab, "contacts")
     |> assign_company(company)
     |> assign(
       :company_conversations,
       Conversations.list_company_conversations(socket.assigns.account, company.id)
     )}
  end

  defp assign_company(socket, company) do
    socket
    |> assign(:company, company)
    |> assign(:company_contacts, Companies.list_company_contacts(company))
    |> assign(:profile_form, to_form(FormModal.company_params(company), as: "company"))
  end

  @impl true
  def handle_event("set-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("profile-validate", %{"company" => params}, socket) do
    changeset = Companies.change_company(socket.assigns.company, params)

    {:noreply,
     assign(socket, :profile_form, to_form(changeset, as: "company", action: :validate))}
  end

  def handle_event("profile-save", %{"company" => params}, socket) do
    case Companies.update_company(socket.assigns.company, params) do
      {:ok, updated} ->
        {:noreply,
         socket |> assign_company(updated) |> put_flash(:info, "Company profile updated.")}

      {:error, changeset} ->
        {:noreply,
         assign(socket, :profile_form, to_form(changeset, as: "company", action: :validate))}
    end
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

    {:noreply,
     socket
     |> put_flash(:info, "Company deleted.")
     |> push_navigate(to: ~p"/app/companies")}
  end

  @impl true
  def handle_info({:company_saved, company}, socket),
    do: {:noreply, assign_company(socket, company)}

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
end
