defmodule ChatwooterWeb.Components.NewConversation.ContactSelector do
  @moduledoc """
  Linha "To:" do compose — port de
  `components-next/NewConversation/components/ContactSelector.vue` (com o `TagInput.vue`
  em modo `single` + `allow-create` e o `DropdownMenu.vue` dos resultados).
  """
  use ChatwooterWeb, :component

  alias ChatwooterWeb.ComposeConversation

  attr :compose, :map, required: true

  def compose_contact_selector(assigns) do
    assigns =
      assigns
      |> assign(:suggestion, ComposeConversation.create_suggestion(assigns.compose))
      |> assign(:invalid_query?, ComposeConversation.invalid_query?(assigns.compose))

    ~H"""
    <div class="relative flex-1 px-4 py-3 overflow-y-visible">
      <div class="flex items-baseline w-full gap-3 min-h-7">
        <label class="text-sm font-medium text-n-slate-11 whitespace-nowrap">To:</label>
        <div
          :if={@compose.contact}
          id="compose-selected-contact"
          class={[
            "flex items-center gap-1.5 rounded-md bg-n-alpha-2 min-h-7 min-w-0",
            if(@compose.contact_locked?, do: "px-3", else: "pl-3 pr-1")
          ]}
        >
          <span class="text-sm truncate text-n-slate-12">
            {ComposeConversation.contact_label(@compose.contact)}
          </span>
          <.next_button
            :if={!@compose.contact_locked?}
            id="compose-clear-contact"
            variant={:ghost}
            icon="ph-x"
            color={:slate}
            size={:xs}
            phx-click="compose:clear_contact"
          />
        </div>
        <div
          :if={!@compose.contact}
          class="flex flex-wrap w-full gap-2 border border-transparent focus:outline-none flex-1 min-h-7"
          phx-click-away={@compose.show_contacts_dropdown && JS.push("compose:close_contacts")}
        >
          <div class="relative flex items-center gap-2 flex-1 min-w-[200px] w-full">
            <.form
              for={%{}}
              as={:compose_contact}
              id="compose-contact-search"
              class="relative flex items-center justify-between w-full gap-3 whitespace-nowrap"
              phx-change="compose:search"
              phx-submit="compose:add_contact"
            >
              <input
                id="compose-contact-input"
                name="q"
                type={ComposeConversation.input_type(@compose)}
                value={@compose.query}
                autocomplete="off"
                phx-debounce="400"
                phx-mounted={JS.focus()}
                placeholder="Enter at least 2 characters to search by name, email, or phone number"
                class={[
                  "flex w-full min-w-0 text-sm h-6 !mb-0 border-0 rounded-none outline-none outline-0 bg-transparent dark:bg-transparent placeholder:text-n-slate-10 dark:placeholder:text-n-slate-10 disabled:cursor-not-allowed disabled:opacity-50 text-n-slate-12 dark:text-n-slate-12 transition-all duration-500 ease-in-out",
                  @invalid_query? && "!text-n-ruby-9 dark:!text-n-ruby-9",
                  @compose.errors[:contact] &&
                    "placeholder:!text-n-ruby-9 dark:placeholder:!text-n-ruby-9"
                ]}
              />
            </.form>
            <div
              :if={@compose.show_contacts_dropdown}
              id="compose-contacts-dropdown"
              class="bg-n-alpha-3 backdrop-blur-[100px] border-0 outline outline-1 outline-n-container absolute rounded-xl z-[100] flex flex-col min-w-[136px] shadow-lg pt-2 overflow-hidden left-0 top-8 max-h-56 w-[inherit] max-w-md dark:!outline-n-slate-5"
            >
              <div class="flex flex-col gap-2 overflow-y-auto min-h-0 px-2 pb-2">
                <button
                  :for={contact <- @compose.contacts}
                  id={"compose-contact-option-#{contact.id}"}
                  type="button"
                  phx-click="compose:select_contact"
                  phx-value-id={contact.id}
                  class="inline-flex items-center justify-start w-full h-8 min-w-0 gap-2 px-2 py-1.5 transition-all duration-200 ease-in-out border-0 rounded-lg hover:bg-n-alpha-1 dark:hover:bg-n-alpha-2 text-n-slate-12"
                >
                  <.avatar name={contact.name} size={20} />
                  <span class="min-w-0 text-sm font-420 truncate">
                    {ComposeConversation.contact_option_label(contact)}
                  </span>
                </button>
                <button
                  :if={@suggestion}
                  id="compose-contact-create"
                  type="button"
                  phx-click="compose:create_contact"
                  class="inline-flex items-center justify-start w-full h-8 min-w-0 gap-2 px-2 py-1.5 transition-all duration-200 ease-in-out border-0 rounded-lg hover:bg-n-alpha-1 dark:hover:bg-n-alpha-2 text-n-slate-12"
                >
                  <.avatar name={@suggestion} size={20} />
                  <span class="min-w-0 text-sm font-420 truncate">{@suggestion}</span>
                </button>
                <div
                  :if={@compose.contacts == [] and is_nil(@suggestion)}
                  class="text-sm text-n-slate-11 px-2 py-1.5"
                >
                  No results found.
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
