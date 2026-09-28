defmodule ChatwooterWeb.Components.Conversation.BulkActionMenu do
  @moduledoc """
  The `DropdownMenu` of each bulk action: `BulkLabelActions.vue` (pick, then apply),
  `BulkUpdateActions.vue`, `BulkAgentActions.vue` and `BulkTeamActions.vue` (pick, then confirm).
  """
  use ChatwooterWeb, :component

  @positions %{
    labels: "-right-[6.5rem] 2xl:right-0 bottom-8 w-60 max-h-80",
    status: "-right-[4.5rem] 2xl:right-0 bottom-8 w-36",
    agent: "-right-10 2xl:right-0 bottom-8 w-60 max-h-80",
    team: "-right-2 bottom-8 w-60 max-h-80"
  }

  attr :kind, :atom, required: true, values: [:labels, :status, :agent, :team]
  attr :action, :atom, default: :assign
  attr :labels, :list, default: []
  attr :picked, :list, default: []
  attr :statuses, :list, default: []
  attr :agents, :list, default: []
  attr :teams, :list, default: []
  attr :pending, :map, default: nil
  attr :count, :integer, default: 0

  def conversation_bulk_action_menu(assigns) do
    assigns = assign(assigns, :position, @positions[assigns.kind])

    ~H"""
    <.searchable_list
      id={"bulk-#{@kind}-menu"}
      class={[
        "bg-n-alpha-3 backdrop-blur-[100px] outline outline-1 outline-n-container absolute rounded-xl z-50 flex flex-col min-w-[136px] shadow-lg pt-2 overflow-hidden",
        @position
      ]}
    >
      <div :if={@kind != :status} class="relative shrink-0 px-2 mb-2">
        <span class="absolute ph-magnifying-glass size-3.5 top-2.5 left-5" />
        <input
          type="search"
          data-search-input
          form="searchable-list-detached"
          placeholder="Search"
          class="w-full h-8 py-2 pl-10 pr-2 text-sm focus:outline-none border-none rounded-lg bg-n-alpha-black2 dark:bg-n-solid-1 text-n-slate-12"
        />
      </div>
      <div class="flex flex-col gap-1 overflow-y-auto min-h-0 px-2 pb-2">
        <%= case @kind do %>
          <% :labels -> %>
            <.item
              :for={label <- @labels}
              id={"bulk-label-#{label.id}"}
              label={label.title}
              search
              selected={label.title in @picked}
              phx-click="bulk:toggle_label"
              phx-value-title={label.title}
            >
              <span
                class="rounded-md h-3 w-3 flex-shrink-0 border border-solid border-n-weak"
                style={"background-color: #{label.color}"}
              />
            </.item>
          <% :status -> %>
            <%= for {status, label, icon} <- @statuses do %>
              <%!-- Snooze opens the command bar snooze list in Chatwoot; it needs roadmap 1.2 "Snooze". --%>
              <.item
                id={"bulk-status-#{status}"}
                label={label}
                phx-click={status != :snoozed && "bulk:status"}
                phx-value-status={status}
              >
                <span class={[icon, "size-4 flex-shrink-0"]} />
              </.item>
            <% end %>
          <% :agent -> %>
            <.item
              :for={agent <- [nil | @agents]}
              id={"bulk-agent-#{(agent && agent.id) || "none"}"}
              label={(agent && available_name(agent)) || "None"}
              search
              selected={@pending != nil && @pending.id == (agent && agent.id)}
              phx-click="bulk:pick_agent"
              phx-value-id={(agent && agent.id) || "none"}
            >
              <.avatar name={(agent && available_name(agent)) || "None"} size={20} />
            </.item>
          <% :team -> %>
            <.item
              :for={team <- [nil | @teams]}
              id={"bulk-team-#{(team && team.id) || "none"}"}
              label={(team && team.name) || "None"}
              search
              selected={@pending != nil && @pending.id == (team && team.id)}
              phx-click="bulk:pick_team"
              phx-value-id={(team && team.id) || "none"}
            />
        <% end %>
        <p
          :if={@kind != :status}
          data-search-empty
          hidden
          class="text-sm text-n-slate-11 px-2 py-1.5 mb-0"
        >
          No results found.
        </p>
      </div>
      <div
        :if={@kind == :labels}
        class="sticky bottom-0 rounded-b-md px-2 py-2 z-20 bg-n-alpha-3 backdrop-blur-[4px]"
      >
        <.next_button
          id="bulk-apply-labels"
          size={:sm}
          class="w-full"
          label={if(@action == :remove, do: "Remove selected labels", else: "Assign selected labels")}
          disabled={@picked == []}
          phx-click="bulk:apply_labels"
        />
      </div>
      <div
        :if={@kind in [:agent, :team] && @pending}
        id="bulk-confirmation"
        class="pt-2 pb-2 px-2 border-t border-n-weak sticky bottom-0 rounded-b-md z-20 bg-n-alpha-3 backdrop-blur-[4px]"
      >
        <div class="flex flex-col gap-2">
          <p :if={@pending.id} class="text-xs text-n-slate-11 px-1 mb-0">
            Are you sure you want to assign <strong class="text-n-slate-12">{@count}</strong>
            {conversations(@count)} to <strong class="text-n-slate-12">{@pending.name}</strong>?
          </p>
          <p :if={!@pending.id} class="text-xs text-n-slate-11 px-1 mb-0">
            Are you sure you want to unassign <strong class="text-n-slate-12">{@count}</strong>
            {conversations(@count)}?
          </p>
          <div class="flex gap-2">
            <.next_button
              id="bulk-cancel"
              size={:sm}
              variant={:faded}
              color={:slate}
              class="flex-1"
              label="Cancel"
              phx-click="bulk:cancel"
            />
            <.next_button
              id="bulk-confirm"
              size={:sm}
              class="flex-1"
              label="Yes"
              phx-click="bulk:confirm"
            />
          </div>
        </div>
      </div>
    </.searchable_list>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :selected, :boolean, default: false
  attr :search, :boolean, default: false
  attr :rest, :global, include: ~w(phx-click phx-value-title phx-value-status phx-value-id)
  slot :inner_block

  # DropdownMenu.vue item: thumbnail slot, label and the trailing check of selected items.
  defp item(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      data-search-item={@search}
      data-search-text={@search && @label}
      class={[
        "inline-flex items-center justify-start w-full h-8 min-w-0 gap-2 px-2 py-1.5 transition-all duration-200 ease-in-out border-0 rounded-lg hover:bg-n-alpha-1 dark:hover:bg-n-alpha-2 text-n-slate-12",
        @selected && "bg-n-alpha-1 dark:bg-n-solid-active"
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
      <span class="min-w-0 text-sm font-420 truncate flex-1 text-start">{@label}</span>
      <span :if={@selected} class="ph-check size-4 text-n-blue-11 flex-shrink-0" />
    </button>
    """
  end

  defp conversations(1), do: "conversation"
  defp conversations(_), do: "conversations"
end
