defmodule ChatwooterWeb.Components.Conversation.ChatListHeader do
  @moduledoc """
  Port de `components/ChatListHeader.vue` + `ConversationBasicFilter.vue` (status e ordenação)
  e do `SelectMenu.vue`. As opções válidas ficam aqui para o `ConversationsLive.Index` validar eventos.
  """
  use ChatwooterWeb, :component

  @statuses [
    {"open", "Open"},
    {"resolved", "Resolved"},
    {"pending", "Pending"},
    {"snoozed", "Snoozed"},
    {"all", "All"}
  ]

  @sorts [
    {"last_activity_at_asc", "Last activity: Oldest first"},
    {"last_activity_at_desc", "Last activity: Newest first"},
    {"created_at_desc", "Created at: Newest first"},
    {"created_at_asc", "Created at: Oldest first"},
    {"unread", "Unread Count: Highest first"},
    {"priority_desc", "Priority: Highest first"},
    {"priority_asc", "Priority: Lowest first"},
    {"priority_desc_created_at_asc", "Priority: Highest first, Created: Oldest first"},
    {"waiting_since_asc", "Pending Response: Longest first"},
    {"waiting_since_desc", "Pending Response: Shortest first"}
  ]

  def status_label(status), do: @statuses |> List.keyfind(status, 0, {status, status}) |> elem(1)
  def valid_status?(status), do: List.keymember?(@statuses, status, 0)
  def valid_sort?(sort), do: List.keymember?(@sorts, sort, 0)

  attr :title, :string, required: true
  attr :status, :string, required: true
  attr :sort, :string, required: true

  # ChatListHeader.vue (sem filtros avançados/pastas aplicados)
  def chat_list_header(assigns) do
    assigns = assign(assigns, statuses: @statuses, sorts: @sorts)

    ~H"""
    <div id="chat-list-header" class="flex items-center justify-between gap-2 px-3 h-[3.25rem]">
      <div class="flex items-center justify-center min-w-0">
        <h1 class="text-base font-medium truncate text-n-slate-12" title={@title}>{@title}</h1>
        <span
          id="chat-list-status"
          class="px-2 py-1 my-0.5 mx-1 rounded-md capitalize bg-n-slate-3 text-xxs text-n-slate-12 shrink-0"
        >
          {status_label(@status)}
        </span>
      </div>
      <div class="flex items-center gap-1">
        <%!-- Filtros avançados ainda não existem; botão só visual por ora --%>
        <div class="relative">
          <.next_button
            id="toggleConversationFilterButton"
            icon="ph-funnel-simple"
            color={:slate}
            variant={:faded}
            size={:xs}
            title="Filter conversations"
          />
        </div>
        <div
          id="chat-sort-menu"
          class="relative flex"
          phx-click-away={JS.set_attribute({"hidden", ""}, to: "#chat-sort-menu-body")}
        >
          <.next_button
            icon="ph-arrows-down-up"
            color={:slate}
            variant={:faded}
            size={:xs}
            title="Sort conversations"
            phx-click={JS.toggle_attribute({"hidden", ""}, to: "#chat-sort-menu-body")}
          />
          <div
            id="chat-sort-menu-body"
            hidden
            class="mt-1 bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak w-72 rounded-xl p-4 absolute z-40 top-full left-0"
          >
            <div class="flex items-center justify-between gap-2">
              <span class="text-sm truncate text-n-slate-12">Status</span>
              <.select_menu
                id="chat-status"
                event="chat:set_status"
                param="status"
                value={@status}
                options={@statuses}
              />
            </div>
            <div class="flex items-center justify-between gap-2 mt-4">
              <span class="text-sm truncate text-n-slate-12">Order by</span>
              <.select_menu
                id="chat-sort"
                event="chat:set_sort"
                param="sort"
                value={@sort}
                options={@sorts}
              />
            </div>
          </div>
        </div>
        <.next_button
          icon="ph-arrow-line-right"
          color={:slate}
          variant={:faded}
          size={:xs}
          title="Switch view layout"
          class="flex-shrink-0 md:inline-flex hidden"
        />
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :event, :string, required: true
  attr :param, :string, required: true
  attr :value, :string, required: true
  attr :options, :list, required: true

  # components-next/selectmenu/SelectMenu.vue (sub-menu à direita)
  defp select_menu(assigns) do
    assigns =
      assign(
        assigns,
        :label,
        assigns.options |> List.keyfind(assigns.value, 0, {nil, ""}) |> elem(1)
      )

    ~H"""
    <div
      id={"#{@id}-select"}
      class="relative flex flex-col gap-1 w-fit"
      phx-click-away={JS.set_attribute({"hidden", ""}, to: "##{@id}-options")}
    >
      <.next_button
        icon="ph-caret-down"
        trailing_icon
        size={:sm}
        color={:slate}
        variant={:faded}
        label={@label}
        class="w-fit! max-w-40"
        phx-click={JS.toggle_attribute({"hidden", ""}, to: "##{@id}-options")}
      />
      <div
        id={"#{@id}-options"}
        hidden
        class="absolute select-none max-w-64 flex flex-col gap-1 bg-n-alpha-3 backdrop-blur-[100px] p-1 top-0 shadow-lg z-40 rounded-lg border border-n-weak dark:border-n-strong/50 left-full ml-1"
      >
        <.next_button
          :for={{value, label} <- @options}
          id={"#{@id}-option-#{value}"}
          label={label}
          icon={if(value == @value, do: "ph-check")}
          size={:sm}
          variant={:ghost}
          color={:slate}
          trailing_icon
          aria-selected={to_string(value == @value)}
          class={["justify-end! px-2.5! h-7!", value == @value && "bg-n-alpha-2!"]}
          phx-click={
            JS.push(@event, value: %{@param => value})
            |> JS.set_attribute({"hidden", ""}, to: "##{@id}-options")
          }
        />
      </div>
    </div>
    """
  end
end
