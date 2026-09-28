defmodule ChatwooterWeb.Components.Conversation.DeleteConversationDialog do
  @moduledoc """
  Delete confirmation of `components/ChatList.vue` (`Dialog.vue`, type alert). Shown by server
  state instead of the `<dialog>` of `next_dialog/1`, since the menu action opens it.
  """
  use ChatwooterWeb, :component

  attr :conversation, :map, required: true

  def conversation_delete_dialog(assigns) do
    ~H"""
    <div
      id="delete-conversation-dialog"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-n-alpha-black1 backdrop-blur-[4px]"
      phx-window-keydown="card:cancel_delete"
      phx-key="Escape"
    >
      <div
        role="alertdialog"
        aria-modal="true"
        phx-click-away="card:cancel_delete"
        class="flex flex-col w-full max-w-lg gap-6 p-6 text-start bg-n-alpha-3 backdrop-blur-[100px] shadow-xl rounded-xl"
      >
        <div class="flex flex-col gap-2">
          <h3 class="text-base font-medium leading-6 text-n-slate-12">
            Delete conversation #{@conversation.display_id}
          </h3>
          <p class="mb-0 text-sm text-n-slate-11">
            Are you sure you want to delete this conversation?
          </p>
        </div>
        <div class="flex items-center justify-between w-full gap-3">
          <.next_button
            variant={:faded}
            color={:slate}
            label="Cancel"
            class="w-full"
            phx-click="card:cancel_delete"
          />
          <.next_button
            id="confirm-delete-conversation"
            color={:ruby}
            label="Delete"
            class="w-full"
            phx-click="card:confirm_delete"
          />
        </div>
      </div>
    </div>
    """
  end
end
