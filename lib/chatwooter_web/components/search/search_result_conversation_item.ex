defmodule ChatwooterWeb.Components.Search.SearchResultConversationItem do
  @moduledoc """
  Conversa encontrada — port de `modules/search/components/SearchResultConversationItem.vue`
  (+ o mapeamento de `SearchResultConversationsList.vue`). Espera a conversa com
  `inbox` e `contact_inbox.contact` carregados.
  """
  use ChatwooterWeb, :component

  alias ChatwooterWeb.TimeAgo

  attr :conversation, :map, required: true

  def search_result_conversation_item(assigns) do
    conversation = assigns.conversation
    contact = conversation.contact_inbox && conversation.contact_inbox.contact

    info_items =
      Enum.reject(
        [
          {"From", contact && contact.name},
          {"Email", contact && contact.email},
          {"Subject", (conversation.additional_attributes || %{})["mail_subject"]}
        ],
        fn {_label, value} -> value in [nil, ""] end
      )

    assigns = assign(assigns, :info_items, info_items)

    ~H"""
    <.link
      id={"search-conversation-#{@conversation.id}"}
      navigate={~p"/app?conversation_id=#{@conversation.id}"}
      class="flex flex-col w-full outline-1 outline outline-n-container -outline-offset-1 group/cardLayout rounded-xl bg-n-solid-2 hover:bg-n-slate-2 dark:hover:bg-n-solid-3"
    >
      <div class="flex w-full flex-col justify-start gap-2 px-4 py-3 items-start">
        <div class="flex items-center min-w-0 justify-between gap-2 w-full h-7 mb-1">
          <div class="flex items-center gap-3">
            <div class="flex items-center gap-1.5 flex-shrink-0">
              <span class="ph-hash flex-shrink-0 text-n-slate-11 size-4" />
              <span class="text-n-slate-12 text-sm leading-4">{@conversation.display_id}</span>
            </div>
            <div :if={@conversation.inbox} class="w-px h-3 bg-n-strong" />
            <div :if={@conversation.inbox} class="flex items-center gap-1.5 flex-shrink-0">
              <div class="flex items-center justify-center flex-shrink-0 rounded-full bg-n-alpha-2 size-4">
                <.channel_icon
                  inbox={@conversation.inbox}
                  class="flex-shrink-0 text-n-slate-11 size-2.5"
                />
              </div>
              <span class="text-sm leading-4 text-n-slate-12">{@conversation.inbox.name}</span>
            </div>
          </div>
          <span
            title={TimeAgo.exact(@conversation.inserted_at)}
            class="text-sm font-normal min-w-0 truncate text-n-slate-11"
          >
            {TimeAgo.long(@conversation.inserted_at)}
          </span>
        </div>
        <div class="flex flex-wrap gap-x-2 gap-y-1.5 items-center">
          <%= for {{label, value}, index} <- Enum.with_index(@info_items) do %>
            <h5 class="m-0 text-sm min-w-0 text-n-slate-12 truncate">
              <span class="text-sm leading-4 font-normal text-n-slate-11">{label}:</span>
              {value}
            </h5>
            <div :if={index < length(@info_items) - 1} class="w-px h-3 bg-n-strong" />
          <% end %>
        </div>
      </div>
    </.link>
    """
  end
end
