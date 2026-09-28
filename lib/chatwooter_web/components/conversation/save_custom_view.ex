defmodule ChatwooterWeb.Components.Conversation.SaveCustomView do
  @moduledoc "Port of components-next/filter/SaveCustomView.vue, rendered in the header's `save_popover` slot."
  use ChatwooterWeb, :component

  attr :form, Phoenix.HTML.Form, required: true
  attr :error, :string, default: nil

  def conversation_save_custom_view(assigns) do
    ~H"""
    <div
      id="save-custom-view"
      class="z-40 max-w-3xl lg:w-[500px] overflow-visible w-full border border-n-weak bg-n-alpha-3 backdrop-blur-[100px] shadow-lg rounded-xl p-6 grid gap-6"
    >
      <h3 class="text-base font-medium leading-6 text-n-slate-12">
        Do you want to save this filter?
      </h3>
      <.form for={@form} id="save-filter-form" phx-submit="filter:save" class="w-full grid gap-6">
        <.next_input field={@form[:name]} placeholder="Name your filter to refer it later." />
        <p :if={@error} role="alert" class="text-sm text-n-ruby-11">{@error}</p>
        <div class="flex flex-row justify-end w-full gap-2">
          <.next_button
            label="Cancel"
            variant={:faded}
            color={:slate}
            size={:sm}
            phx-click="filter:close"
          />
          <.next_button id="confirm-save-filter" label="Save filter" type="submit" size={:sm} />
        </div>
      </.form>
    </div>
    """
  end
end
