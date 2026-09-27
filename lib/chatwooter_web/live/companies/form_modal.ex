defmodule ChatwooterWeb.CompaniesLive.FormModal do
  @moduledoc """
  Eventos do modal de criar/editar empresa, compartilhados por `CompaniesLive.Index` e
  `CompaniesLive.Show` (`on_mount` + `attach_hook`). Depois de salvar, avisa a página com
  `{:company_saved, company}` para cada uma atualizar o que mostra.
  """
  import Phoenix.Component, only: [assign: 3, to_form: 2]
  import Phoenix.LiveView, only: [attach_hook: 4, put_flash: 3]

  alias Chatwooter.Companies
  alias Chatwooter.Companies.Company

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> assign(:modal_open, false)
     |> assign(:editing, nil)
     |> assign(:form, blank_form())
     |> attach_hook(:company_form_modal, :handle_event, &handle_event/3)}
  end

  defp handle_event("new", _params, socket) do
    {:halt,
     socket |> assign(:editing, nil) |> assign(:modal_open, true) |> assign(:form, blank_form())}
  end

  defp handle_event("edit", %{"id" => id}, socket) do
    company = Companies.get_company!(socket.assigns.account, id)

    {:halt,
     socket
     |> assign(:editing, company)
     |> assign(:modal_open, true)
     |> assign(:form, to_form(company_params(company), as: "company"))}
  end

  defp handle_event("validate", %{"company" => params}, socket) do
    changeset = Companies.change_company(socket.assigns.editing || %Company{}, params)
    {:halt, assign(socket, :form, to_form(changeset, as: "company", action: :validate))}
  end

  defp handle_event("save", %{"company" => params}, socket) do
    result =
      case socket.assigns.editing do
        nil -> Companies.create_company(socket.assigns.account, params)
        company -> Companies.update_company(company, params)
      end

    case result do
      {:ok, saved} ->
        send(self(), {:company_saved, saved})

        {:halt,
         socket
         |> assign(:editing, nil)
         |> assign(:modal_open, false)
         |> put_flash(:info, "Company saved.")}

      {:error, changeset} ->
        {:halt, assign(socket, :form, to_form(changeset, as: "company", action: :validate))}
    end
  end

  defp handle_event("close-modal", _params, socket) do
    {:halt, socket |> assign(:modal_open, false) |> assign(:editing, nil)}
  end

  defp handle_event(_event, _params, socket), do: {:cont, socket}

  @doc "Params do formulário de empresa (também usado pelo perfil no detalhe)."
  def company_params(company) do
    %{
      "name" => company.name || "",
      "domain" => company.domain || "",
      "description" => company.description || ""
    }
  end

  defp blank_form,
    do: to_form(%{"name" => "", "domain" => "", "description" => ""}, as: "company")
end
