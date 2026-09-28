defmodule ChatwooterWeb.Components.Conversation.CardSelect do
  @moduledoc """
  Selection checkbox of the conversation cards (the `Checkbox` of `ConversationCard.vue` and
  `CardAvatar.vue`). It sits inside the card link, so the click must not open the conversation.
  """
  use ChatwooterWeb, :component

  attr :id, :string, required: true
  attr :conversation_id, :integer, required: true
  attr :selected, :boolean, default: false
  attr :class, :any, default: nil

  def conversation_card_select(assigns) do
    ~H"""
    <span id={@id} phx-hook=".CardSelect" data-conversation-id={@conversation_id} class={@class}>
      <.next_checkbox checked={@selected} />
      <script :type={Phoenix.LiveView.ColocatedHook} name=".CardSelect">
        export default {
          mounted() {
            this.el.addEventListener("click", e => {
              e.preventDefault()
              e.stopPropagation()
              this.pushEvent("bulk:toggle", {id: this.el.dataset.conversationId})
            })
          }
        }
      </script>
    </span>
    """
  end
end
