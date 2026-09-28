defmodule ChatwooterWeb.Components.Conversation.ConversationCard do
  @moduledoc """
  Port de `components/widgets/conversation/ConversationCard.vue` (layout condensado).
  """
  use ChatwooterWeb, :component

  import ChatwooterWeb.Components.Conversation.{CardLabels, CardLink, CardSelect}

  alias ChatwooterWeb.Components.Conversation.CardHelpers
  import ChatwooterWeb.Components.Conversation.MessagePreview

  alias ChatwooterWeb.TimeAgo

  attr :id, :string, required: true
  attr :conversation, :map, required: true
  attr :path, :string, required: true
  attr :active, :boolean, default: false
  attr :selected, :boolean, default: false
  attr :account_labels, :list, default: []
  attr :show_inbox_name, :boolean, default: false
  attr :show_assignee, :boolean, default: false

  # ConversationCard.vue (layout condensado)
  def conversation_card(assigns) do
    conv = assigns.conversation
    unread = conv.unread_count || 0
    assignee_name = conv.assignee && available_name(conv.assignee)
    priority_icon = with {icon, _} <- CardHelpers.priority(conv.priority), do: icon

    show_meta =
      assigns.show_inbox_name or (assigns.show_assignee and assignee_name != nil) or
        priority_icon != nil

    assigns =
      assign(assigns,
        contact: conv.contact_inbox.contact,
        inbox: conv.contact_inbox.inbox,
        unread: unread,
        assignee_name: assignee_name,
        priority_icon: priority_icon,
        show_meta: show_meta,
        last_message: CardHelpers.last_message(conv.messages || []),
        preview_class: [
          if(unread > 0, do: "font-medium text-n-slate-12", else: "text-n-slate-11"),
          unread > 0 && "pr-4"
        ]
      )

    ~H"""
    <.conversation_card_link
      id={@id}
      path={@path}
      conversation_id={@conversation.id}
      data-layout="condensed"
      class={[
        "relative flex items-start flex-grow-0 flex-shrink-0 w-auto max-w-full py-0 cursor-pointer conversation border-b border-n-slate-3 hover:border-n-surface-1 hover:bg-n-alpha-1 dark:hover:bg-n-alpha-3 group hover:z-[1] before:content-[none] before:absolute before:-top-px before:inset-x-0 before:h-px before:bg-n-surface-1 before:pointer-events-none hover:before:content-[''] px-3",
        @active && "active animate-card-select bg-n-background border-n-surface-1!",
        @selected && "selected bg-n-slate-2 border-n-surface-1!"
      ]}
    >
      <div class="relative group/avatar">
        <.avatar
          name={@contact.name}
          size={32}
          class={if(@show_inbox_name, do: "mt-8", else: "mt-4")}
        />
        <%!-- Avatar #overlay of ConversationCard.vue: the checkbox shows on hover or when selected. --%>
        <.conversation_card_select
          id={"#{@id}-select"}
          conversation_id={@conversation.id}
          selected={@selected}
          class={[
            "items-center justify-center rounded-full cursor-pointer absolute left-0 z-10 size-8 backdrop-blur-[2px]",
            if(@show_inbox_name, do: "top-8", else: "top-4"),
            if(@selected, do: "flex", else: "hidden group-hover/avatar:flex")
          ]}
        />
      </div>
      <div class="px-0 py-3 flex-1 min-w-0">
        <div :if={@show_meta} class="flex items-center min-w-0 gap-1 ml-2">
          <div
            :if={@show_inbox_name}
            data-role="inbox"
            title={@inbox.name}
            class="flex items-center gap-0.5 min-w-0 flex-1"
          >
            <.channel_icon inbox={@inbox} class="size-4 flex-shrink-0 text-n-slate-11" />
            <span class="truncate text-label-small text-n-slate-11">{@inbox.name}</span>
          </div>
          <div class={[
            "flex items-baseline gap-2 flex-shrink-0",
            !@show_inbox_name && "flex-1 justify-between"
          ]}>
            <span
              :if={@show_assignee && @assignee_name}
              data-role="assignee"
              class="text-n-slate-11 text-xs font-medium leading-3 py-0.5 px-0 inline-flex items-center gap-px truncate"
            >
              <span class="ph-user size-3 text-n-slate-11 flex-shrink-0" />
              <span class="truncate">{@assignee_name}</span>
            </span>
            <span
              :if={@priority_icon}
              class={[@priority_icon, "flex-shrink-0 size-3.5 text-n-slate-5"]}
            />
          </div>
        </div>
        <h4 class={[
          "conversation--user text-sm my-0 mx-2 capitalize pt-0.5 text-ellipsis overflow-hidden whitespace-nowrap flex-1 min-w-0 pr-16 text-n-slate-12",
          if(@unread > 0, do: "font-semibold", else: "font-medium")
        ]}>
          {@contact.name}
        </h4>
        <.message_preview message={@last_message} class={@preview_class} />
        <%!-- SLACardLabel (#before slot) needs Enterprise SLA policies and the SLA job: not ported. --%>
        <.conversation_card_labels
          id={"#{@id}-labels"}
          conversation_labels={CardHelpers.labels(@conversation)}
          account_labels={@account_labels}
          class="mt-0.5 mx-2 mb-0"
        />
        <div class={["absolute flex flex-col right-3", if(@show_meta, do: "top-8", else: "top-4")]}>
          <span class="ml-auto font-normal leading-4 text-xxs">
            <div
              data-role="time"
              title={"Created at: #{TimeAgo.exact(@conversation.inserted_at)}\nLast activity: #{TimeAgo.exact(@conversation.last_activity_at)}"}
              class="ml-auto leading-4 text-xxs text-n-slate-10 hover:text-n-slate-11"
            >
              <span>
                {TimeAgo.short(@conversation.inserted_at)} • {TimeAgo.short(
                  @conversation.last_activity_at
                )}
              </span>
            </div>
          </span>
          <span
            :if={@unread > 0}
            data-role="unread"
            class="bg-n-teal-9 rounded-full h-4 min-w-4 max-w-5 px-1 w-fit font-medium text-xxs leading-3 text-white inline-grid place-items-center flex-shrink-0 ml-auto mt-1"
          >
            {if(@unread > 9, do: "9+", else: @unread)}
          </span>
        </div>
      </div>
    </.conversation_card_link>
    """
  end
end
