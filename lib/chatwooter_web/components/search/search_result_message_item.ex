defmodule ChatwooterWeb.Components.Search.SearchResultMessageItem do
  @moduledoc """
  Mensagem encontrada — port de `modules/search/components/SearchResultMessageItem.vue`
  com `MessageContent.vue` e o `getName` de `SearchResultMessagesList.vue`.

  Desvios: o "Read more / Read less" (`useExpandableContent`, que mede o DOM)
  vira um `line-clamp-2`; os chips de anexo (File/Audio + transcrição) ainda não
  têm port; e o link abre a conversa sem o `messageId` (a thread ainda não rola
  até a mensagem).
  """
  use ChatwooterWeb, :component

  alias ChatwooterWeb.TimeAgo

  attr :message, :map, required: true
  attr :query, :string, required: true

  def search_result_message_item(assigns) do
    assigns =
      assigns
      |> assign(:author, author(assigns.message))
      |> assign(:segments, highlight(assigns.message.content || "", assigns.query))

    ~H"""
    <.link
      id={"search-message-#{@message.id}"}
      navigate={~p"/app?conversation_id=#{@message.conversation_id}"}
      class="flex flex-col w-full outline-1 outline outline-n-container -outline-offset-1 group/cardLayout rounded-xl bg-n-solid-2 hover:bg-n-slate-2 dark:hover:bg-n-solid-3"
    >
      <div class="flex w-full flex-col justify-start gap-2 px-4 py-3 items-start">
        <div class="flex items-center min-w-0 justify-between gap-2 w-full h-7 mb-1">
          <div class="flex items-center gap-3">
            <div class="flex items-center gap-1.5 flex-shrink-0">
              <span class="ph-hash flex-shrink-0 text-n-slate-11 size-4" />
              <span class="text-n-slate-12 text-sm leading-4">
                {@message.conversation.display_id}
              </span>
            </div>
            <div :if={@message.inbox} class="w-px h-3 bg-n-strong" />
            <div :if={@message.inbox} class="flex items-center gap-1.5 flex-shrink-0">
              <div class="flex items-center justify-center flex-shrink-0 rounded-full bg-n-alpha-2 size-4">
                <.channel_icon inbox={@message.inbox} class="flex-shrink-0 text-n-slate-11 size-2.5" />
              </div>
              <span class="text-sm leading-4 text-n-slate-12">{@message.inbox.name}</span>
            </div>
            <div :if={@message.private} class="w-px h-3 bg-n-strong" />
            <div
              :if={@message.private}
              class="flex items-center text-n-amber-11 gap-1.5 flex-shrink-0"
            >
              <span class="ph-lock-key flex-shrink-0 size-3.5" />
              <span class="text-sm leading-4">Private note</span>
            </div>
          </div>
          <span
            title={TimeAgo.exact(@message.inserted_at)}
            class="text-sm font-normal min-w-0 truncate text-n-slate-11"
          >
            {TimeAgo.long(@message.inserted_at)}
          </span>
        </div>
        <div class="break-words text-n-slate-11 text-sm leading-relaxed line-clamp-2">
          <span class="text-n-slate-11 font-medium leading-4">{@author} wrote: </span>
          <span class="message-content text-n-slate-12 [&_.searchkey--highlight]:text-n-slate-12 [&_.searchkey--highlight]:font-semibold"><%= for {kind, text} <- @segments do %>
            <span
              :if={kind == :match}
              class="searchkey--highlight"
            >{text}</span>
            <%= if kind == :text do %>
              {text}
            <% end %>
          <% end %></span>
        </div>
      </div>
    </.link>
    """
  end

  # getName: o remetente do Chatwoot; mensagens recebidas aqui não guardam o
  # sender, então caem no contato da conversa. Sem nenhum dos dois, "Bot".
  defp author(%{sender: %{name: name}}) when name not in [nil, ""], do: name

  defp author(%{message_type: :incoming, conversation: %{contact_inbox: %{contact: contact}}})
       when not is_nil(contact),
       do: contact.name

  defp author(_message), do: "Bot"

  # highlightedContent: marca cada ocorrência do termo, sem diferenciar caixa
  defp highlight(content, query) do
    case String.trim(query) do
      "" ->
        [{:text, content}]

      term ->
        ~r/(#{Regex.escape(term)})/iu
        |> Regex.split(content, include_captures: true, trim: true)
        |> Enum.map(&highlight_part(&1, term))
    end
  end

  defp highlight_part(part, term) do
    if String.downcase(part) == String.downcase(term),
      do: {:match, part},
      else: {:text, part}
  end
end
