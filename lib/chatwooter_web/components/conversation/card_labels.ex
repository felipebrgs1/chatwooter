defmodule ChatwooterWeb.Components.Conversation.CardLabels do
  @moduledoc """
  Port of `components/widgets/conversation/conversationCardComponents/CardLabels.vue` with each
  label as `woot-label` (`ui/Label.vue`, variant smooth, small). The labels that do not fit are
  hidden on the client, like `computeVisibleLabelPosition`; the chevron shows them all.

  `compact` is `components-next/.../CardLabelsV5.vue` with `disable-toggle` (expanded card):
  compact `Label`s and a "+N" counter instead of the chevron.
  """
  use ChatwooterWeb, :component

  attr :id, :string, required: true
  attr :conversation_labels, :list, required: true
  attr :account_labels, :list, required: true
  attr :compact, :boolean, default: false
  attr :class, :any, default: nil

  def conversation_card_labels(assigns) do
    assigns =
      assign(
        assigns,
        :active,
        Enum.filter(assigns.account_labels, &(&1.title in assigns.conversation_labels))
      )

    ~H"""
    <div
      :if={@active != []}
      id={@id}
      phx-hook=".CardLabels"
      data-compact={@compact}
      data-titles={Enum.map_join(@active, ", ", & &1.title)}
      class={@class}
    >
      <div
        data-labels-row
        class={[
          "flex min-w-0 gap-y-1",
          if(@compact,
            do: "items-center flex-shrink min-h-6 gap-x-1.5 justify-end",
            else: "items-end flex-shrink"
          )
        ]}
      >
        <%= for label <- @active do %>
          <div
            :if={!@compact}
            data-label
            title={label.description}
            class="label smooth small inline-flex items-center gap-1 me-1 mb-0 h-5 py-0.5 px-1 max-w-[calc(100%-0.5rem)] rounded-[4px] border border-solid border-n-strong bg-transparent text-xs font-medium leading-tight text-n-slate-11 dark:text-n-slate-12"
          >
            <span
              class="inline-block flex-shrink-0 w-2 h-2 rounded-sm shadow-sm"
              style={"background: #{label.color}"}
            />
            <span class="whitespace-nowrap text-ellipsis overflow-hidden">{label.title}</span>
          </div>
          <div
            :if={@compact}
            data-label
            title={label.description}
            class="-outline-offset-1 outline outline-1 inline-flex items-center flex-shrink-0 bg-n-label-color outline-n-label-border text-n-slate-12 px-1.5 h-6 gap-1 rounded-md"
          >
            <span class="rounded-sm flex-shrink-0 size-1.5" style={"background: #{label.color}"} />
            <span class="whitespace-nowrap text-label-small">{label.title}</span>
          </div>
        <% end %>
        <button
          :if={!@compact}
          data-expand
          type="button"
          hidden
          title="Show labels"
          class="h-5 py-0 px-1 flex-shrink-0 me-6 ms-0 rtl:rotate-180 text-n-slate-11 border-n-strong"
        >
          <span data-expand-icon class="ph-caret-right size-3" />
        </button>
        <span
          :if={@compact}
          data-count
          hidden
          class="inline-flex items-center h-6 py-0 px-1.5 gap-0.5 flex-shrink-0 rounded-md bg-n-button-color text-xs cursor-default"
        >
          <span class="ph-plus size-3 text-n-slate-10" />
          <span data-count-text class="text-n-slate-11"></span>
        </span>
      </div>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".CardLabels">
        // CardLabels.vue → computeVisibleLabelPosition / onShowLabels. The chevron lives inside the
        // card link, so its click must not open the conversation.
        export default {
          mounted() {
            this.showAll = false
            this.button = this.el.querySelector("[data-expand]")
            if (this.button) {
              this.button.addEventListener("click", e => {
                e.preventDefault()
                e.stopPropagation()
                this.showAll = !this.showAll
                this.layout()
              })
            }
            this.observer = new ResizeObserver(() => this.layout())
            this.observer.observe(this.el)
            this.layout()
          },
          updated() { this.layout() },
          destroyed() { this.observer && this.observer.disconnect() },
          layout() {
            const compact = this.el.dataset.compact !== undefined
            const row = this.el.querySelector("[data-labels-row]")
            const labels = [...this.el.querySelectorAll("[data-label]")]
            row.classList.toggle("flex-wrap", this.showAll)
            row.classList.toggle("flex-row", this.showAll)
            labels.forEach(label => label.classList.remove("invisible", "absolute"))
            // CardLabelsV5 keeps 46px for the counter; CardLabels.vue adds an 8px gap per label.
            const available = compact ? this.el.clientWidth - 46 : this.el.clientWidth
            let offset = 0
            let hidden = 0
            labels.forEach(label => {
              offset += label.offsetWidth + (compact ? 6 : 8)
              if (offset > available || hidden > 0) hidden++
              if (hidden > 0 && !this.showAll) label.classList.add("invisible", "absolute")
            })
            if (compact) {
              const count = this.el.querySelector("[data-count]")
              const all = hidden === labels.length
              count.hidden = hidden === 0
              count.querySelector("[data-count-text]").textContent = all ? `${labels.length} labels` : hidden
              count.title = all ? this.el.dataset.titles : ""
            } else {
              this.button.hidden = !(hidden > 0 && labels.length > 1)
              this.button.title = this.showAll ? "Hide labels" : "Show labels"
              const icon = this.el.querySelector("[data-expand-icon]")
              icon.className = `${this.showAll ? "ph-caret-left" : "ph-caret-right"} size-3`
            }
          }
        }
      </script>
    </div>
    """
  end
end
