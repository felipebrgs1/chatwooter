defmodule ChatwooterWeb.Components.Next.Dialog do
  @moduledoc "Port de `components-next/dialog/Dialog.vue` sobre `<dialog>` nativo."
  use ChatwooterWeb, :base_component

  import ChatwooterWeb.Components.Next.Button

  @doc """
  `components-next/dialog/Dialog.vue` sobre `<dialog>` nativo. Abra com
  `JS.dispatch("dialog:open", to: "#id")`; o confirmar envia `phx-submit={@on_confirm}`.
  """
  attr :id, :string, required: true
  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :type, :atom, default: :edit, values: [:edit, :alert]
  attr :confirm_label, :string, default: "Confirm"
  attr :cancel_label, :string, default: "Cancel"
  attr :on_confirm, :any, required: true
  attr :width, :string, default: "max-w-lg"
  slot :inner_block

  def next_dialog(assigns) do
    ~H"""
    <dialog
      id={@id}
      phx-hook=".Dialog"
      class={[
        "w-full m-auto transition-all duration-300 ease-in-out shadow-xl rounded-xl bg-transparent overflow-visible backdrop:bg-n-alpha-black1 backdrop:backdrop-blur-[4px]",
        @width
      ]}
    >
      <form
        phx-submit={@on_confirm}
        class="flex flex-col w-full h-auto gap-6 p-6 overflow-visible text-start align-middle bg-n-alpha-3 backdrop-blur-[100px] shadow-xl rounded-xl"
      >
        <div :if={@title || @description} class="flex flex-col gap-2">
          <h3 class="text-base font-medium leading-6 text-n-slate-12">{@title}</h3>
          <p :if={@description} class="mb-0 text-sm text-n-slate-11">{@description}</p>
        </div>
        {render_slot(@inner_block)}
        <div class="flex items-center justify-between w-full gap-3">
          <.next_button
            variant={:faded}
            color={:slate}
            label={@cancel_label}
            class="w-full"
            phx-click={JS.dispatch("dialog:close", to: "##{@id}")}
          />
          <.next_button
            type="submit"
            color={if(@type == :edit, do: :blue, else: :ruby)}
            label={@confirm_label}
            class="w-full"
            phx-click={JS.dispatch("dialog:close", to: "##{@id}")}
          />
        </div>
      </form>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".Dialog">
        export default {
          mounted() {
            this.el.addEventListener("dialog:open", () => this.el.showModal())
            this.el.addEventListener("dialog:close", () => this.el.close())
            // clique no backdrop fecha (OnClickOutside do Dialog.vue)
            this.el.addEventListener("click", e => { if (e.target === this.el) this.el.close() })
          }
        }
      </script>
    </dialog>
    """
  end
end
