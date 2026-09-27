defmodule ChatwooterWeb.Components.Companies.CompanyFormModal do
  @moduledoc "Modal de criar/editar empresa, usado na lista e no detalhe (eventos em `CompaniesLive.FormModal`)."
  use ChatwooterWeb, :component

  attr :form, Phoenix.HTML.Form, required: true
  attr :editing, :any, default: nil

  def company_form_modal(assigns) do
    ~H"""
    <div
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
    """
  end
end
