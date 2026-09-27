defmodule ChatwooterWeb.Components.NewConversation.ComposeConversation do
  @moduledoc """
  Popover "nova conversa" — port de
  `chatwoot/app/javascript/dashboard/components-next/NewConversation/ComposeConversation.vue`,
  `components/ComposeNewConversationForm.vue`, `components/MessageEditor.vue` e do
  `popover/Popover.vue` que o envolve. Estado e eventos em `ChatwooterWeb.ComposeConversation`.

  O gatilho é um botão comum com `phx-click={JS.push("compose:toggle", value: %{anchor: id})}`
  e `data-compose-trigger`; o popover é renderizado fora do contêiner do gatilho (o
  `Popover.vue` usa Teleport) e o hook o posiciona em `fixed` junto dele.
  """
  use ChatwooterWeb, :component

  import ChatwooterWeb.Components.NewConversation.{
    ActionButtons,
    ContactSelector,
    InboxSelector
  }

  alias ChatwooterWeb.ComposeConversation

  attr :compose, :map, required: true
  attr :user, :map, required: true
  attr :align, :string, default: "end", values: ~w(start end)

  def compose_conversation(assigns) do
    assigns = assign(assigns, :hotkey, hotkey(assigns.user))

    ~H"""
    <div
      id="compose-conversation-backdrop"
      class="fixed inset-0 z-[9999] flex items-start pt-[clamp(3rem,15vh,12rem)] justify-center bg-n-alpha-black1 md:contents"
    >
      <div
        id="compose-conversation"
        phx-hook=".ComposePopover"
        data-anchor={@compose.anchor}
        data-align={@align}
        data-hotkey={@hotkey}
        data-popover-content
        class="relative flex flex-col w-full max-w-lg max-h-[calc(100vh-4rem)] mx-4 md:fixed md:z-[9999] md:w-auto md:max-w-none md:mx-0 bg-n-alpha-3 backdrop-blur-[100px] shadow-xl rounded-xl"
      >
        <div class="flex-1 min-h-0 overflow-y-auto overscroll-contain rounded-xl">
          <div class="w-full md:w-[42rem] divide-y divide-n-strong overflow-visible transition-all duration-300 ease-in-out top-full flex flex-col bg-n-alpha-3 border border-n-strong shadow-sm backdrop-blur-[100px] rounded-xl min-w-0 max-h-[calc(100vh-8rem)]">
            <div class="flex-1 overflow-y-auto divide-y divide-n-strong">
              <.compose_contact_selector compose={@compose} />
              <.compose_inbox_selector compose={@compose} />
              <%!-- EmailOptions.vue (assunto, Cc, Bcc) só aparece em inbox de email: fora do escopo v1 --%>
              <.form
                :if={
                  !ComposeConversation.whatsapp?(@compose) and
                    !ComposeConversation.no_inbox?(@compose)
                }
                for={%{}}
                as={:compose_message}
                id="compose-message-form"
                class="flex-1 h-full px-4 py-4"
                phx-change="compose:change"
                phx-submit="compose:send"
              >
                <%!-- MessageEditor.vue usa o editor ProseMirror (formatação, variáveis,
                     Captain); aqui é texto simples até o editor rico ser portado --%>
                <textarea
                  id="compose-message-input"
                  name="message"
                  phx-debounce="300"
                  placeholder="Write your message here..."
                  aria-invalid={to_string(@compose.errors[:message] == true)}
                  class={[
                    "block w-full min-h-[12rem] max-h-[12.5rem] p-0 text-sm resize-none border-0 bg-transparent outline-none focus:ring-0 text-n-slate-12 placeholder:text-n-slate-10",
                    @compose.errors[:message] && "placeholder:!text-n-ruby-9"
                  ]}
                >{Phoenix.HTML.Form.normalize_value("textarea", @compose.message)}</textarea>
              </.form>
            </div>
            <.compose_action_buttons compose={@compose} hotkey={@hotkey} />
          </div>
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".ComposePopover">
      // useDropdownPosition.js (modo fixed): SAFE_MARGIN e GAP
      const MARGIN = 16
      const GAP = 8
      const mobile = () => window.matchMedia("(max-width: 767px)").matches

      export default {
        mounted() {
          this.onClick = e => {
            if (this.el.contains(e.target) || e.target.closest("[data-compose-trigger]")) return
            this.pushEvent("compose:close", {})
          }
          this.onKey = e => {
            if (e.key === "Escape") return this.pushEvent("compose:close", {})
            if (e.key !== "Enter" || e.target.id !== "compose-message-input") return
            const hotkey = this.el.dataset.hotkey
            const cmd = e.metaKey || e.ctrlKey
            if ((hotkey === "enter" && !cmd && !e.shiftKey) || (hotkey === "cmd_enter" && cmd)) {
              e.preventDefault()
              e.target.form.requestSubmit()
            }
          }
          this.onResize = () => this.position()
          document.addEventListener("click", this.onClick, true)
          document.addEventListener("keydown", this.onKey)
          window.addEventListener("resize", this.onResize)
          this.position()
        },

        updated() { this.position() },

        destroyed() {
          document.removeEventListener("click", this.onClick, true)
          document.removeEventListener("keydown", this.onKey)
          window.removeEventListener("resize", this.onResize)
        },

        // Abaixo do gatilho (ou acima, se não couber), alinhado pela borda start/end
        position() {
          const trigger = document.getElementById(this.el.dataset.anchor)
          if (mobile() || !trigger) return this.el.removeAttribute("style")

          const t = trigger.getBoundingClientRect()
          const {width, height} = this.el.getBoundingClientRect()
          const winW = window.innerWidth, winH = window.innerHeight
          const below = winH - t.bottom
          const above = below < height + MARGIN && (t.top >= height + MARGIN || t.top > below)
          const style = {}

          if (above) {
            style.bottom = `${winH - t.top + GAP}px`
            style.maxHeight = `${t.top - GAP - MARGIN}px`
          } else {
            style.top = `${t.bottom + GAP}px`
            style.maxHeight = `${below - GAP - MARGIN}px`
          }

          if (this.el.dataset.align === "start") {
            if (t.left + width > winW - MARGIN) style.right = `${MARGIN}px`
            else style.left = `${Math.max(MARGIN, t.left)}px`
          } else if (t.right - width < MARGIN) {
            style.left = `${MARGIN}px`
          } else {
            style.right = `${winW - t.right}px`
          }

          this.el.removeAttribute("style")
          Object.assign(this.el.style, style)
        }
      }
    </script>
    """
  end

  # useUISettings#isEditorHotKeyEnabled: sem `editor_message_key`, `enter_to_send_enabled` decide.
  defp hotkey(user) do
    settings = user.ui_settings || %{}

    case settings["editor_message_key"] do
      key when key in ["enter", "cmd_enter"] -> key
      _other -> if settings["enter_to_send_enabled"], do: "enter", else: "cmd_enter"
    end
  end
end
