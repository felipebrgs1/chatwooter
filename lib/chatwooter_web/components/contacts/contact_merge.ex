defmodule ChatwooterWeb.Components.Contacts.ContactMerge do
  @moduledoc """
  Aba Merge: `ContactsSidebar/ContactMerge.vue` + `ContactsForm/ContactMergeForm.vue`.
  """
  use ChatwooterWeb, :component

  attr :contact, :map, required: true
  attr :merge_candidates, :list, required: true
  attr :merge_primary_id, :string, default: nil
  attr :merge_error, :string, default: nil

  # ContactMerge.vue + ContactsForm/ContactMergeForm.vue
  def contact_merge(assigns) do
    assigns =
      assign(
        assigns,
        :candidates,
        Enum.map(assigns.merge_candidates, &%{value: to_string(&1.id), label: merge_label(&1)})
      )

    ~H"""
    <div id="contact-merge" class="flex flex-col gap-8 px-6">
      <div class="flex flex-col gap-2">
        <h4 class="text-base text-n-slate-12">Merge contact</h4>
        <p class="text-sm text-n-slate-11">
          Combine two profiles into one, including all attributes and conversations. In case of conflict, the primary contact’s attributes will take precedence.
        </p>
      </div>
      <div class="flex flex-col">
        <div class="flex flex-col gap-2">
          <div class="flex items-center justify-between h-5 gap-2">
            <label class="text-sm text-n-slate-12">Primary contact</label>
            <span class="flex items-center justify-center w-24 h-5 text-xs rounded-md text-n-teal-11 bg-n-alpha-2">
              To be saved
            </span>
          </div>
          <.combobox
            id="merge-primary"
            options={@candidates}
            value={@merge_primary_id}
            event="select-merge-primary"
            placeholder="Search for primary contact"
            search_placeholder="Search for a contact"
            empty_state="No contacts found"
          />
          <p :if={@merge_error} class="mt-0 mb-0 text-xs truncate text-n-ruby-9">{@merge_error}</p>
        </div>
        <div class="relative flex justify-center gap-2 top-4">
          <div :for={_ <- 1..3} class="relative w-4 h-8">
            <div class="absolute w-0 h-0 border-l-[4px] border-r-[4px] border-b-[6px] border-l-transparent border-r-transparent border-n-strong translate-x-[4px] -translate-y-[4px]" />
            <div class="absolute w-[1px] h-full bg-n-strong left-1/2 -translate-x-1/2" />
          </div>
        </div>
        <div class="flex flex-col gap-2">
          <div class="flex items-center justify-between h-5 gap-2">
            <label class="text-sm text-n-slate-12">To be merged</label>
            <span class="flex items-center justify-center w-24 h-5 text-xs rounded-md text-n-ruby-11 bg-n-alpha-2">
              To be deleted
            </span>
          </div>
          <div class="border border-n-strong h-[60px] gap-2 flex items-center rounded-xl p-3">
            <.avatar name={@contact.name} size={32} />
            <div class="flex flex-col w-full min-w-0 gap-1">
              <span class="text-sm leading-4 truncate text-n-slate-11">{@contact.name}</span>
              <span class="text-sm leading-4 truncate text-n-slate-11">{@contact.email}</span>
            </div>
          </div>
        </div>
      </div>
      <div class="flex items-center justify-between gap-3">
        <.next_button
          variant={:faded}
          color={:slate}
          label="Cancel"
          class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
          phx-click="merge-cancel"
        />
        <.next_button id="merge-confirm" label="Merge contact" class="w-full" phx-click="merge" />
      </div>
    </div>
    """
  end

  defp merge_label(contact) do
    [contact.name, contact.email || contact.phone_number]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" · ")
  end
end
