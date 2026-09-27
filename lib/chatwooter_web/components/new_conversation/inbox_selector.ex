defmodule ChatwooterWeb.Components.NewConversation.InboxSelector do
  @moduledoc """
  Linha "Via:" do compose — port de
  `components-next/NewConversation/components/InboxSelector.vue` e `InboxEmptyState.vue`.
  """
  use ChatwooterWeb, :component

  alias ChatwooterWeb.ComposeConversation

  attr :compose, :map, required: true

  def compose_inbox_selector(assigns) do
    ~H"""
    <div
      :if={ComposeConversation.no_inbox?(@compose)}
      id="compose-no-inbox"
      class="flex items-center w-full px-4 py-3 dark:bg-n-amber-11/15 bg-n-amber-3"
    >
      <span class="text-sm dark:text-n-amber-11 text-n-amber-11">
        There are no available inboxes to start a conversation with this contact.
      </span>
    </div>
    <div
      :if={!ComposeConversation.no_inbox?(@compose)}
      class="flex items-center flex-1 w-full gap-3 px-4 py-3 overflow-y-visible"
    >
      <label class="mb-0.5 text-sm font-medium text-n-slate-11 whitespace-nowrap">Via:</label>
      <div
        :if={@compose.target}
        id="compose-target-inbox"
        class="flex items-center gap-1.5 rounded-md bg-n-alpha-2 truncate pl-3 pr-1 h-7 min-w-0"
      >
        <span class="text-sm truncate text-n-slate-12">{@compose.target.inbox.name}</span>
        <.next_button
          id="compose-clear-inbox"
          variant={:ghost}
          icon="ph-x"
          color={:slate}
          size={:xs}
          class="flex-shrink-0"
          phx-click="compose:clear_inbox"
        />
      </div>
      <div
        :if={!@compose.target}
        class="relative flex items-center h-7"
        phx-click-away={@compose.show_inboxes_dropdown && JS.push("compose:close_inboxes")}
      >
        <.next_button
          id="compose-show-inboxes"
          label="Show inboxes"
          variant={:link}
          size={:sm}
          color={if(@compose.errors[:inbox], do: :ruby, else: :slate)}
          disabled={is_nil(@compose.contact)}
          class="hover:!no-underline"
          phx-click="compose:toggle_inboxes"
        />
        <div
          :if={@compose.contactable_inboxes != [] and @compose.show_inboxes_dropdown}
          id="compose-inboxes-dropdown"
          class="bg-n-alpha-3 backdrop-blur-[100px] border-0 outline outline-1 outline-n-container absolute rounded-xl flex flex-col min-w-[136px] shadow-lg pt-2 overflow-hidden left-0 z-[100] top-8 max-h-56 w-fit max-w-sm dark:!outline-n-slate-5"
        >
          <div class="flex flex-col gap-2 overflow-y-auto min-h-0 px-2 pb-2">
            <button
              :for={%{inbox: inbox} <- @compose.contactable_inboxes}
              id={"compose-inbox-option-#{inbox.id}"}
              type="button"
              phx-click="compose:select_inbox"
              phx-value-id={inbox.id}
              class="inline-flex items-center justify-start w-full h-8 min-w-0 gap-2 px-2 py-1.5 transition-all duration-200 ease-in-out border-0 rounded-lg hover:bg-n-alpha-1 dark:hover:bg-n-alpha-2 text-n-slate-12"
            >
              <.channel_icon inbox={inbox} class="flex-shrink-0 size-3.5" />
              <span class="min-w-0 text-sm font-420 truncate">{inbox.name}</span>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
