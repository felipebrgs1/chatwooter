defmodule ChatwooterWeb.Components.NewConversation.ActionButtons do
  @moduledoc """
  Rodapé do compose — port de `components-next/NewConversation/components/ActionButtons.vue`
  e do gatilho de `WhatsAppOptions.vue`.
  """
  use ChatwooterWeb, :component

  alias ChatwooterWeb.ComposeConversation

  attr :compose, :map, required: true
  attr :hotkey, :string, required: true, doc: "\"enter\" ou \"cmd_enter\" (isEditorHotKeyEnabled)"

  def compose_action_buttons(assigns) do
    whatsapp? = ComposeConversation.whatsapp?(assigns.compose)

    assigns =
      assigns
      |> assign(:whatsapp?, whatsapp?)
      |> assign(:regular?, not whatsapp?)
      |> assign(:no_inbox?, ComposeConversation.no_inbox?(assigns.compose))
      |> assign(:key_code, if(assigns.hotkey == "enter", do: "↵", else: "⌘ + ↵"))

    ~H"""
    <div class="flex items-center justify-between w-full h-[3.25rem] gap-2 px-4 py-3">
      <div class="flex gap-2 items-center">
        <%!-- WhatsAppOptions.vue: templates ainda não são sincronizados da Meta, então o
             seletor fica só visual. Sem template não dá para abrir conversa no WhatsApp
             (fora da janela de 24h a Meta só aceita mensagens de template). --%>
        <.next_button
          :if={@whatsapp?}
          id="compose-whatsapp-templates"
          icon="ph-whatsapp-logo"
          label="Select template"
          color={:slate}
          size={:sm}
          class="!text-xs font-medium"
          disabled
        />
        <%!-- Emoji picker e assinatura ainda não existem; botões só visuais por ora.
             Anexos (FileUpload) só aparecem em inbox de email/web widget — fora do escopo. --%>
        <.next_button
          :if={!@whatsapp? and !@no_inbox?}
          icon="ph-smiley"
          color={:slate}
          size={:sm}
          class="!w-10"
        />
        <.next_button
          :if={@compose.target && @regular?}
          icon="ph-signature"
          color={:slate}
          size={:sm}
          class="!w-10"
        />
      </div>

      <div class="flex gap-2 items-center">
        <.next_button
          id="compose-discard"
          label="Discard"
          variant={:faded}
          color={:slate}
          size={:sm}
          class="!text-xs font-medium"
          phx-click="compose:discard"
        />
        <.next_button
          :if={@regular?}
          id="compose-send"
          type="submit"
          form="compose-message-form"
          label={"Send (#{@key_code})"}
          size={:sm}
          class="!text-xs font-medium"
          phx-disable-with="Send"
        />
      </div>
    </div>
    """
  end
end
