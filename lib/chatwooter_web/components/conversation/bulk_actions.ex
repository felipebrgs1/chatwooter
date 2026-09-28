defmodule ChatwooterWeb.Components.Conversation.BulkActions do
  @moduledoc """
  Port of `components/widgets/conversation/conversationBulkActions/Index.vue`: the floating bar
  over the conversation list. Each button opens its `BulkActionMenu` (Bulk*Actions.vue).
  """
  use ChatwooterWeb, :component

  import ChatwooterWeb.Components.Conversation.BulkActionMenu

  attr :count, :integer, required: true
  attr :all_selected, :boolean, default: false
  attr :menu, :atom, default: nil
  attr :statuses, :list, default: []
  attr :labels, :list, default: []
  attr :picked, :list, default: []
  attr :agents, :list, default: []
  attr :teams, :list, default: []
  attr :pending, :map, default: nil
  attr :class, :any, default: nil

  def conversation_bulk_actions(assigns) do
    ~H"""
    <div
      id="bulk-actions"
      class={[
        "px-2 absolute bottom-20 sm:bottom-4 left-1/2 -translate-x-1/2 z-30 w-full origin-bottom",
        @class
      ]}
    >
      <div
        :if={@all_selected}
        id="bulk-all-selected-alert"
        class="bg-n-amber-2 outline -outline-offset-1 outline-1 outline-n-amber-5 rounded-lg text-sm mb-2 py-1.5 px-2 text-n-amber-text"
      >
        Conversations visible on this page are only selected.
      </div>
      <div class="flex items-center justify-between gap-2 p-2 bg-n-button-color outline outline-1 -outline-offset-1 rounded-[10px] outline-n-weak shadow-[0_0_12px_0_rgba(27,40,59,0.08)]">
        <div class="ms-0.5 flex items-center gap-1 min-w-0">
          <button
            id="bulk-select-all"
            type="button"
            class="cursor-pointer flex items-center gap-1.5 min-w-0 text-sm text-n-slate-12"
            phx-click="bulk:select_all"
          >
            <.next_checkbox checked={@all_selected} indeterminate={!@all_selected} />
            <span title={"#{@count} selected"} class="cursor-pointer truncate">
              {@count} selected
            </span>
          </button>
          <div class="w-px h-3 bg-n-weak rounded-lg ms-1 flex-shrink-0" />
          <.next_button
            id="bulk-clear"
            label="Clear"
            variant={:ghost}
            size={:sm}
            class="text-n-blue-11! px-1! h-6! flex-shrink-0"
            phx-click="bulk:clear"
          />
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
          <.menu_button
            id="bulk-assign-labels"
            menu={:assign_labels}
            open={@menu}
            icon="ph-tag"
            title="Assign labels"
          >
            <.conversation_bulk_action_menu
              kind={:labels}
              labels={@labels}
              picked={@picked}
              action={:assign}
            />
          </.menu_button>
          <%!-- Phosphor has no tag-minus (i-woot-tag-remove); tag-simple keeps the two buttons apart. --%>
          <.menu_button
            id="bulk-remove-labels"
            menu={:remove_labels}
            open={@menu}
            icon="ph-tag-simple"
            title="Remove labels"
          >
            <.conversation_bulk_action_menu
              kind={:labels}
              labels={@labels}
              picked={@picked}
              action={:remove}
            />
          </.menu_button>
          <.menu_button
            id="bulk-status"
            menu={:status}
            open={@menu}
            icon="ph-arrow-circle-up"
            title="Change status"
          >
            <.conversation_bulk_action_menu kind={:status} statuses={@statuses} />
          </.menu_button>
          <.menu_button
            id="bulk-agent"
            menu={:agent}
            open={@menu}
            icon="ph-user-switch"
            title="Assign agent"
          >
            <.conversation_bulk_action_menu
              kind={:agent}
              agents={@agents}
              pending={@pending}
              count={@count}
            />
          </.menu_button>
          <.menu_button id="bulk-team" menu={:team} open={@menu} icon="ph-users" title="Assign team">
            <.conversation_bulk_action_menu
              kind={:team}
              teams={@teams}
              pending={@pending}
              count={@count}
            />
          </.menu_button>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :menu, :atom, required: true
  attr :open, :atom, default: nil
  attr :icon, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  # The click-away sits on the wrapper so the button itself toggles the menu.
  defp menu_button(assigns) do
    ~H"""
    <div class="relative" phx-click-away={@open == @menu && "bulk:close_menu"}>
      <.next_button
        id={@id}
        icon={@icon}
        color={:slate}
        variant={:ghost}
        size={:xs}
        title={@title}
        class={@open == @menu && "bg-n-alpha-2"}
        phx-click="bulk:menu"
        phx-value-menu={@menu}
      />
      <%= if @open == @menu do %>
        {render_slot(@inner_block)}
      <% end %>
    </div>
    """
  end
end
