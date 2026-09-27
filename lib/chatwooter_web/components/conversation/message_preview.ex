defmodule ChatwooterWeb.Components.Conversation.MessagePreview do
  @moduledoc """
  Port de `components/widgets/conversation/MessagePreview.vue` (+ o ramo "No Messages" do card).
  """
  use ChatwooterWeb, :component

  # ATTACHMENT_ICONS (shared/constants/messages.js) + textos CHAT_LIST.ATTACHMENTS
  @attachments %{
    image: {"ph-image", "Picture message"},
    audio: {"ph-headphones", "Audio message"},
    video: {"ph-video-camera", "Video message"},
    file: {"ph-file", "File Attachment"},
    location: {"ph-map-pin", "Location"},
    fallback: {"ph-link", "has shared a url"},
    ig_reel: {nil, "Instagram Reel"},
    contact: {nil, "Shared contact"},
    embed: {nil, "Embedded content"}
  }

  attr :message, :map, default: nil
  attr :class, :any, default: nil

  # MessagePreview.vue (+ o ramo "No Messages" do card)
  def message_preview(%{message: nil} = assigns) do
    ~H"""
    <p
      data-role="preview"
      class={[
        "text-n-slate-11 text-sm my-0 mx-2 leading-6 h-6 flex-1 min-w-0 overflow-hidden text-ellipsis whitespace-nowrap",
        @class
      ]}
    >
      <span class="ph-info size-4 -mt-0.5 align-middle inline-block text-n-slate-10" />
      <span class="mx-0.5">No Messages</span>
    </p>
    """
  end

  def message_preview(assigns) do
    message = assigns.message
    attachment = List.first(message.attachments || [])

    assigns =
      assign(assigns,
        type_icon: type_icon(message),
        attachment: attachment && Map.get(@attachments, attachment.file_type)
      )

    ~H"""
    <div
      data-role="preview"
      class={[
        "overflow-hidden text-ellipsis whitespace-nowrap my-0 mx-2 leading-6 h-6 flex-1 min-w-0 text-sm",
        @class
      ]}
    >
      <span
        :if={@type_icon}
        class={[@type_icon, "size-4 -mt-0.5 align-middle text-n-slate-11 inline-block"]}
      />
      <%= cond do %>
        <% present?(@message.content) -> %>
          <span>{@message.content}</span>
        <% @attachment -> %>
          <span>
            <span
              :if={elem(@attachment, 0)}
              class={[
                elem(@attachment, 0),
                "size-4 -mt-0.5 align-middle inline-block text-n-slate-11"
              ]}
            />
            {elem(@attachment, 1)}
          </span>
        <% true -> %>
          <span>No content available</span>
      <% end %>
    </div>
    """
  end

  defp type_icon(%{private: true}), do: "ph-lock-simple"
  defp type_icon(%{message_type: :outgoing}), do: "ph-arrow-bend-up-left"
  defp type_icon(%{message_type: :activity}), do: "ph-info"
  defp type_icon(_message), do: nil

  defp present?(content), do: is_binary(content) and String.trim(content) != ""
end
