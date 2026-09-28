defmodule ChatwooterWeb.Components.Conversation.DeleteCustomView do
  @moduledoc "Port of routes/dashboard/customviews/DeleteCustomViews.vue (`woot-delete-modal`)."
  use ChatwooterWeb, :component

  attr :folder, :any, required: true

  def conversation_delete_custom_view(assigns) do
    ~H"""
    <div
      id="delete-filter-confirmation"
      class="fixed inset-0 z-50 flex items-center justify-center bg-n-alpha-black1 backdrop-blur-[4px]"
    >
      <div
        class="w-full max-w-lg m-4 rounded-xl border border-n-weak bg-n-alpha-3 backdrop-blur-[100px] shadow-xl"
        phx-click-away="filter:close"
        role="dialog"
        aria-modal="true"
      >
        <div class="flex flex-col gap-2 px-8 pt-8">
          <h2 class="text-lg font-medium text-n-slate-12">Confirm deletion</h2>
          <p class="text-sm text-n-slate-11">
            Are you sure to delete the filter <strong>{@folder.name}</strong>?
          </p>
        </div>
        <div class="flex items-center justify-end gap-2 p-8">
          <.next_button
            label="No, keep it"
            variant={:faded}
            color={:slate}
            phx-click="filter:close"
          />
          <.next_button
            id="confirm-delete-filter"
            label="Yes, delete"
            color={:ruby}
            phx-click="filter:delete"
          />
        </div>
      </div>
    </div>
    """
  end
end
