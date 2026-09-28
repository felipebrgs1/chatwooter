defmodule ChatwooterWeb.Components.Conversation.ContextMenu do
  @moduledoc """
  Port of `components/widgets/conversation/contextMenu/Index.vue` (with `menuItem.vue` and
  `menuItemWithSubmenu.vue`) inside the fixed container of `components/ui/ContextMenu.vue`.
  """
  use ChatwooterWeb, :component

  # CONVERSATION.PRIORITY.OPTIONS, in the menu order; the Rails enum is low 0 … urgent 3.
  @priorities [
    {nil, "None"},
    {"urgent", "Urgent"},
    {"high", "High"},
    {"medium", "Medium"},
    {"low", "Low"}
  ]
  @priority_keys %{0 => "low", 1 => "medium", 2 => "high", 3 => "urgent"}

  @statuses [
    {:resolved, "Mark as resolved", "ph-check"},
    {:open, "Reopen conversation", "ph-arrow-bend-up-right"},
    {:pending, "Mark as pending", "ph-clock-countdown"}
  ]

  attr :conversation, :map, required: true
  attr :x, :integer, required: true
  attr :y, :integer, required: true
  attr :path, :string, required: true
  attr :labels, :list, default: []
  attr :conversation_labels, :list, default: []
  attr :agents, :list, default: []
  attr :teams, :list, default: []
  attr :admin, :boolean, default: false

  def conversation_context_menu(assigns) do
    current_priority = @priority_keys[assigns.conversation.priority]

    # Assigned labels first, keeping each group's order (filteredLabels).
    labels = Enum.sort_by(assigns.labels, &(&1.title not in assigns.conversation_labels))

    assigns =
      assign(assigns,
        statuses:
          Enum.reject(@statuses, fn {key, _, _} -> key == assigns.conversation.status end),
        priorities: Enum.reject(@priorities, fn {key, _} -> key == current_priority end),
        sorted_labels: labels
      )

    ~H"""
    <div
      id="conversation-context-menu"
      phx-hook=".ConversationContextMenu"
      phx-click-away="card:close_menu"
      phx-window-keydown="card:close_menu"
      phx-key="Escape"
      class="fixed outline-none z-[9999] cursor-pointer"
      style={"left: #{@x}px; top: #{@y}px"}
    >
      <div class="p-1 rounded-md shadow-xl bg-n-alpha-3/50 backdrop-blur-[100px] outline-1 outline outline-n-weak/50">
        <.menu_item
          :if={@conversation.unread_count == 0}
          id="context-menu-mark-unread"
          icon="ph-envelope-simple"
          label="Mark as unread"
          phx-click="card:mark_unread"
        />
        <.menu_item
          :if={@conversation.unread_count > 0}
          id="context-menu-mark-read"
          icon="ph-envelope-open"
          label="Mark as read"
          phx-click="card:mark_read"
        />
        <hr class="m-1 rounded border-b border-n-weak" />
        <.menu_item
          :for={{key, label, icon} <- @statuses}
          id={"context-menu-status-#{key}"}
          icon={icon}
          label={label}
          phx-click="card:status"
          phx-value-status={key}
        />
        <%!-- Snooze needs snoozed_until and the reopen job (roadmap 1.2 "Snooze"): visual only for now. --%>
        <.menu_item
          :if={@conversation.status == :open}
          id="context-menu-snooze"
          icon="ph-moon-stars"
          label="Snooze"
        />
        <hr class="m-1 rounded border-b border-n-weak" />
        <.submenu id="context-menu-priority" icon="ph-warning" label="Priority">
          <.menu_item
            :for={{key, label} <- @priorities}
            id={"context-menu-priority-#{key || "none"}"}
            label={label}
            phx-click="card:priority"
            phx-value-priority={key || ""}
          />
        </.submenu>
        <.submenu
          id="context-menu-labels"
          icon="ph-tag"
          label="Assign label"
          available={@labels != []}
        >
          <.searchable_list id="context-menu-label-search">
            <div class="pb-1 w-[12.5rem] relative">
              <span class="ph-magnifying-glass absolute z-10 -translate-y-1/2 pointer-events-none size-3.5 text-n-slate-10 top-1/2 start-2" />
              <input
                type="search"
                data-search-input
                form="searchable-list-detached"
                placeholder="Search labels"
                class="w-full h-7 ps-8 pe-2 text-xs rounded-lg border-none bg-n-alpha-black2 text-n-slate-12 focus:outline-none"
              />
            </div>
            <div class="overflow-x-hidden overflow-y-auto max-h-[12.5rem]">
              <.menu_item
                :for={label <- @sorted_labels}
                id={"context-menu-label-#{label.id}"}
                label={label.title}
                color={label.color}
                checked={label.title in @conversation_labels}
                data-search-item
                data-search-text={label.title}
                phx-click="card:label"
                phx-value-title={label.title}
              />
              <p data-search-empty hidden class="px-2 py-2 m-0 text-xs text-center text-n-slate-11">
                No labels found
              </p>
            </div>
          </.searchable_list>
        </.submenu>
        <.submenu id="context-menu-agents" icon="ph-user-plus" label="Assign agent">
          <.menu_item
            id="context-menu-agent-none"
            label="None"
            avatar
            phx-click="card:agent"
            phx-value-id=""
          />
          <.menu_item
            :for={agent <- @agents}
            id={"context-menu-agent-#{agent.id}"}
            label={available_name(agent)}
            avatar
            phx-click="card:agent"
            phx-value-id={agent.id}
          />
        </.submenu>
        <.submenu
          id="context-menu-teams"
          icon="ph-users-three"
          label="Assign team"
          available={@teams != []}
        >
          <.menu_item
            :for={team <- @teams}
            id={"context-menu-team-#{team.id}"}
            label={team.name}
            phx-click="card:team"
            phx-value-id={team.id}
          />
        </.submenu>
        <hr class="m-1 rounded border-b border-n-weak" />
        <a
          id="context-menu-open-new-tab"
          href={@path}
          target="_blank"
          rel="noopener noreferrer"
          phx-click="card:close_menu"
          class={item_class()}
        >
          <span class="ph-arrow-square-out size-3.5 flex-shrink-0" />
          <p class="my-0 mx-2 text-xs truncate min-w-0 flex-1">Open in new tab</p>
        </a>
        <.menu_item
          id="context-menu-copy-link"
          icon="ph-copy"
          label="Copy conversation link"
          data-copy={@path}
        />
        <%= if @admin do %>
          <hr class="m-1 rounded border-b border-n-weak" />
          <.menu_item
            id="context-menu-delete"
            icon="ph-trash"
            label="Delete conversation"
            phx-click="card:delete"
          />
        <% end %>
      </div>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".ConversationContextMenu">
        // ContextMenu.vue → calculatePosition: keep the menu inside the viewport.
        export default {
          place() {
            const PADDING = 16
            const {width, height} = this.el.getBoundingClientRect()
            let left = parseFloat(this.el.style.left)
            let top = parseFloat(this.el.style.top)
            if (left + width > window.innerWidth - PADDING) left = window.innerWidth - width - PADDING
            if (top + height > window.innerHeight - PADDING) top = window.innerHeight - height - PADDING
            this.el.style.left = `${Math.max(PADDING, left)}px`
            this.el.style.top = `${Math.max(PADDING, top)}px`
          },
          mounted() {
            this.place()
            this.el.addEventListener("click", async e => {
              const copy = e.target.closest("[data-copy]")
              if (!copy) return
              await navigator.clipboard.writeText(new URL(copy.dataset.copy, window.location.origin).href)
              this.pushEvent("card:link_copied", {})
            })
          },
          updated() { this.place() }
        }
      </script>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, default: nil
  attr :color, :string, default: nil
  attr :checked, :boolean, default: false
  attr :avatar, :boolean, default: false
  attr :rest, :global, include: ~w(data-search-item data-search-text data-copy)

  # menuItem.vue (variants icon / label / label-assigned / agent)
  defp menu_item(assigns) do
    ~H"""
    <div id={@id} role="button" class={item_class()} {@rest}>
      <span :if={@icon} class={[@icon, "size-3.5 flex-shrink-0"]} />
      <span
        :if={@color}
        class="size-4 rounded-full border border-n-strong flex-shrink-0"
        style={"background-color: #{@color}"}
      />
      <.avatar :if={@avatar} name={@label} size={20} class="flex-shrink-0" />
      <p class="my-0 mx-2 text-xs truncate min-w-0 flex-1">{@label}</p>
      <span
        :if={@checked}
        class="ph-check flex-shrink-0 size-3.5 text-n-brand group-hover/item:text-white"
      />
    </div>
    """
  end

  defp item_class,
    do:
      "group/item flex items-center flex-nowrap w-[12.5rem] min-h-7 p-1 rounded-md overflow-hidden cursor-pointer text-n-slate-12 hover:bg-n-brand hover:text-white"

  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :available, :boolean, default: true
  slot :inner_block, required: true

  # menuItemWithSubmenu.vue: the submenu opens on hover.
  # The original flips it left/up near the viewport edge; the list sits on the left, so it opens right.
  defp submenu(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "group/submenu text-n-slate-12 min-w-[12.5rem] w-full p-1 flex items-center h-7 rounded-md relative justify-between hover:bg-n-brand/10 cursor-pointer dark:hover:bg-n-solid-3",
        !@available && "opacity-50 cursor-not-allowed"
      ]}
    >
      <div class="flex items-center h-4">
        <span class={[@icon, "size-3.5"]} />
        <p class="my-0 mx-2 text-xs">{@label}</p>
      </div>
      <span class="ph-caret-right size-3" />
      <div
        :if={@available}
        class="bg-n-alpha-3 backdrop-blur-[100px] p-1 shadow-lg rounded-md absolute top-0 left-full hidden group-hover/submenu:block max-h-[15rem] overflow-y-auto overflow-x-hidden cursor-pointer"
      >
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
