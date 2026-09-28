defmodule ChatwooterWeb.Components.Conversation.ConversationCardExpanded do
  @moduledoc """
  Port of `components-next/Conversation/ConversationCard/ConversationCardExpanded.vue`: one row
  per conversation for the expanded layout, with `CardPriorityIcon`, `CardStatusIcon`,
  `CardAvatar`, `CardContent` and `CardLabelsV5` inline.
  """
  use ChatwooterWeb, :component

  import ChatwooterWeb.Components.Conversation.{CardLabels, CardLink, CardSelect, MessagePreview}

  alias ChatwooterWeb.Components.Conversation.CardHelpers
  alias ChatwooterWeb.TimeAgo

  # CardStatusIcon.vue: i-woot-status-* drawn with Phosphor in the original colors.
  @statuses %{
    open: "ph-circle-notch text-n-blue-9",
    resolved: "ph-check-circle text-n-teal-9",
    pending: "ph-circle-dashed text-n-slate-8",
    snoozed: "ph-moon text-n-amber-9"
  }

  attr :id, :string, required: true
  attr :conversation, :map, required: true
  attr :path, :string, required: true
  attr :active, :boolean, default: false
  attr :selected, :boolean, default: false
  attr :account_labels, :list, default: []
  attr :show_inbox_name, :boolean, default: false

  def conversation_card_expanded(assigns) do
    conv = assigns.conversation
    labels = CardHelpers.labels(conv)

    assigns =
      assign(assigns,
        contact: conv.contact_inbox.contact,
        inbox: conv.contact_inbox.inbox,
        unread: conv.unread_count || 0,
        labels: labels,
        # showAssigneeForExpandedCard is always true on the expanded card.
        assignee_name: conv.assignee && available_name(conv.assignee),
        priority: CardHelpers.priority(conv.priority) || {"ph-cell-signal-none", "None"},
        status_icon: Map.get(@statuses, conv.status, "ph-circle-dashed text-n-slate-10"),
        last_message: CardHelpers.last_message(conv.messages || [])
      )

    ~H"""
    <.conversation_card_link
      id={@id}
      path={@path}
      conversation_id={@conversation.id}
      data-layout="expanded"
      class={[
        "conversation relative cursor-pointer group grid gap-4 items-center px-3 h-12 border-b border-n-slate-3 hover:border-n-surface-1 hover:z-[1] before:content-[none] before:absolute before:-top-px before:inset-x-0 before:h-px before:bg-n-surface-1 before:pointer-events-none hover:before:content-['']",
        @active && "active animate-card-select bg-n-alpha-1 dark:bg-n-alpha-3 border-n-surface-1!",
        @selected && "selected bg-n-slate-2 dark:bg-n-slate-3 border-n-surface-1!",
        !@active && !@selected && "hover:bg-n-alpha-1",
        if(@labels != [],
          do: "grid-cols-[minmax(0,2fr)_minmax(0,1fr)]",
          else: "grid-cols-[minmax(0,2fr)_max-content]"
        )
      ]}
    >
      <div class="flex items-center gap-2 min-w-0 flex-1">
        <div class="flex items-center justify-center flex-shrink-0">
          <.conversation_card_select
            id={"#{@id}-select"}
            conversation_id={@conversation.id}
            selected={@selected}
            class="flex cursor-pointer"
          />
        </div>
        <div class="w-px h-3 bg-n-slate-6 flex-shrink-0" />
        <div class="w-4 flex items-center justify-center flex-shrink-0">
          <span
            data-role="priority"
            title={elem(@priority, 1)}
            class={[elem(@priority, 0), "size-4 text-n-slate-5"]}
          />
        </div>
        <div class="w-4 flex items-center justify-center flex-shrink-0">
          <span :if={@assignee_name} title={@assignee_name} data-role="assignee">
            <.avatar name={@assignee_name} size={14} />
          </span>
          <span :if={!@assignee_name} class="ph-user-circle size-4 text-n-slate-7" />
        </div>
        <div class="w-4 flex items-center justify-center flex-shrink-0">
          <span
            data-role="status"
            title={@conversation.status}
            class={[@status_icon, "size-4 flex-shrink-0"]}
          />
        </div>
        <div class="w-px h-3 bg-n-slate-6 flex-shrink-0" />
        <%= if @show_inbox_name do %>
          <div class="w-20 flex-shrink-0">
            <div title={@inbox.name} class="flex items-center gap-0.5 min-w-0">
              <.channel_icon inbox={@inbox} class="size-4 flex-shrink-0 text-n-slate-11" />
              <span class="truncate text-body-main text-n-slate-11">{@inbox.name}</span>
            </div>
          </div>
          <div class="w-px h-3 bg-n-slate-6 flex-shrink-0" />
        <% end %>
        <div
          title={@conversation.display_id}
          class="h-6 flex items-center gap-1 max-w-20 w-full min-w-0 flex-shrink-0"
        >
          <span class="ph-hash size-3.5 text-n-slate-10 flex-shrink-0" />
          <span data-role="id" class="text-body-main text-n-slate-11 truncate">
            {@conversation.display_id}
          </span>
        </div>
        <div class="relative flex items-center flex-shrink-0">
          <.avatar name={@contact.name} size={24} />
        </div>
        <h4 class="text-heading-3 my-0 capitalize truncate text-n-slate-12 font-medium w-32 flex-shrink-0">
          {@contact.name}
        </h4>
        <div class="grid grid-cols-[1fr_auto] gap-1.5 items-center min-w-0 flex-1">
          <.message_preview
            message={@last_message}
            class={[
              "mx-0! text-body-main",
              if(@unread > 0, do: "text-n-slate-12", else: "text-n-slate-11")
            ]}
          />
          <span
            :if={@unread > 0}
            data-role="unread"
            class="bg-n-teal-9 rounded-full h-4 min-w-4 max-w-5 px-1 w-fit font-medium text-xxs leading-3 text-white inline-grid place-items-center flex-shrink-0"
          >
            {if(@unread > 9, do: "9+", else: @unread)}
          </span>
        </div>
      </div>
      <div class="flex items-center justify-end gap-1.5 flex-shrink-0">
        <div :if={@labels != []} class="min-w-0 w-full">
          <.conversation_card_labels
            id={"#{@id}-labels"}
            conversation_labels={@labels}
            account_labels={@account_labels}
            compact
            class="my-0 justify-end"
          />
        </div>
        <%!-- SLACardLabel needs Enterprise SLA policies and the SLA job: not ported. --%>
        <div class="flex-shrink-0 w-[4.375rem] text-end">
          <span
            data-role="time"
            title={"Created at: #{TimeAgo.exact(@conversation.inserted_at)}\nLast activity: #{TimeAgo.exact(@conversation.last_activity_at)}"}
            class="ml-auto leading-4 font-[440] text-xs! text-n-slate-11"
          >
            {TimeAgo.short(@conversation.inserted_at)} • {TimeAgo.short(
              @conversation.last_activity_at
            )}
          </span>
        </div>
      </div>
    </.conversation_card_link>
    """
  end
end
