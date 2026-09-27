defmodule ChatwooterWeb.Components.Contacts.ContactHistory do
  @moduledoc """
  Aba History: `ContactsSidebar/ContactHistory.vue` com o `ConversationCard` do components-next.
  """
  use ChatwooterWeb, :component

  alias ChatwooterWeb.TimeAgo

  attr :contact, :map, required: true
  attr :conversations, :list, required: true

  # ContactHistory.vue → components-next ConversationCard
  def contact_history(assigns) do
    ~H"""
    <div
      :if={@conversations != []}
      id="contact-history"
      class="px-6 divide-y divide-n-strong [&>*:hover]:border-y-transparent! [&>*:hover+*]:border-t-transparent!"
    >
      <.link
        :for={conv <- @conversations}
        id={"contact-history-#{conv.id}"}
        navigate={~p"/app?conversation_id=#{conv.id}"}
        class="flex w-full gap-3 px-3 py-4 transition-all duration-300 ease-in-out cursor-pointer rounded-none hover:rounded-xl hover:bg-n-alpha-1 dark:hover:bg-n-alpha-3"
      >
        <.avatar name={@contact.name} size={24} />
        <div class="flex flex-col w-full gap-1 min-w-0">
          <div class="flex items-center justify-between h-6 gap-2">
            <h4 class="text-base font-medium truncate text-n-slate-12">{@contact.name}</h4>
            <div class="flex items-center gap-2">
              <div
                title={conv.contact_inbox.inbox.name}
                class="flex items-center justify-center flex-shrink-0 rounded-full bg-n-alpha-2 size-5"
              >
                <.channel_icon
                  inbox={conv.contact_inbox.inbox}
                  class="flex-shrink-0 text-n-slate-11 size-3"
                />
              </div>
              <span class="text-sm text-n-slate-10" title={TimeAgo.exact(conv.last_activity_at)}>
                {TimeAgo.short(conv.last_activity_at)}
              </span>
            </div>
          </div>
          <div class="flex items-end w-full gap-2 pb-1">
            <p class="w-full mb-0 text-sm line-clamp-2 text-n-slate-11">
              {last_message_text(conv)}
            </p>
          </div>
        </div>
      </.link>
    </div>
    <p :if={@conversations == []} class="px-6 py-10 text-sm leading-6 text-center text-n-slate-11">
      There are no previous conversations associated to this contact
    </p>
    """
  end

  defp last_message_text(conv) do
    case conv.messages |> Enum.reject(&(&1.message_type == :activity)) |> List.last() do
      nil -> "No Messages"
      %{content: content} when content not in [nil, ""] -> content
      _message -> "No content available"
    end
  end
end
