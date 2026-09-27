defmodule ChatwooterWeb.Components.Conversation.ChatTypeTabs do
  @moduledoc """
  Port de `components/widgets/ChatTypeTabs.vue` (abas Mine / Unassigned / All).
  """
  use ChatwooterWeb, :component

  @tabs [{"me", "Mine", :mine}, {"unassigned", "Unassigned", :unassigned}, {"all", "All", :all}]

  def valid_tab?(tab), do: List.keymember?(@tabs, tab, 0)

  attr :active, :string, required: true
  attr :counts, :map, required: true

  # ChatTypeTabs.vue → woot-tabs (ui/Tabs) compacto
  def chat_type_tabs(assigns) do
    assigns = assign(assigns, :tabs, @tabs)

    ~H"""
    <div class="flex w-full px-3 -mt-1 py-0 h-10">
      <ul
        class="border-r-0 border-l-0 border-t-0 flex min-w-[6.25rem] py-0 p-0 list-none mb-0"
        role="tablist"
      >
        <li
          :for={{key, name, count_key} <- @tabs}
          class="flex-shrink-0 my-0 mx-2 first:ml-0 last:mr-0 hover:text-n-slate-12 text-sm"
        >
          <a
            id={"chat-tab-#{key}"}
            role="tab"
            aria-selected={to_string(key == @active)}
            phx-click={JS.push("chat:set_tab", value: %{tab: key})}
            class={[
              "flex items-center flex-row select-none cursor-pointer relative after:absolute after:bottom-px after:left-0 after:right-0 after:h-[2px] after:rounded-full after:transition-all after:duration-200 text-button font-medium py-2.5",
              if(key == @active,
                do: "text-n-blue-11 after:bg-n-brand after:opacity-100",
                else: "text-n-slate-11 after:bg-transparent after:opacity-0"
              )
            ]}
          >
            {name}
            <div class={[
              "rounded-full h-5 flex items-center justify-center text-xs font-medium my-0 ml-1 px-1.5 py-0 min-w-[20px]",
              if(key == @active,
                do: "bg-n-blue-3 text-n-blue-11",
                else: "bg-n-alpha-1 text-n-slate-10"
              )
            ]}>
              <span>{Map.get(@counts, count_key, 0)}</span>
            </div>
          </a>
        </li>
      </ul>
    </div>
    """
  end
end
