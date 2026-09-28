defmodule ChatwooterWeb.Components.Conversation.CardLink do
  @moduledoc """
  Root link of both conversation cards (`ConversationItem.vue`): patches to the conversation
  and opens the context menu at the cursor on right click.
  """
  use ChatwooterWeb, :component

  attr :id, :string, required: true
  attr :path, :string, required: true
  attr :conversation_id, :integer, required: true
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(data-layout)
  slot :inner_block, required: true

  def conversation_card_link(assigns) do
    ~H"""
    <.link
      id={@id}
      patch={@path}
      phx-hook=".CardContextMenu"
      data-conversation-id={@conversation_id}
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
      <script :type={Phoenix.LiveView.ColocatedHook} name=".CardContextMenu">
        // ConversationItem.vue → openContextMenu: the menu opens at the cursor.
        export default {
          mounted() {
            this.el.addEventListener("contextmenu", e => {
              e.preventDefault()
              this.pushEvent("card:context_menu", {id: this.el.dataset.conversationId, x: e.clientX, y: e.clientY})
            })
          }
        }
      </script>
    </.link>
    """
  end
end
