defmodule ChatwooterWeb.Components.Contacts.ContactProfile do
  @moduledoc """
  Cabeçalho do detalhe (`Pages/ContactDetails.vue`): avatar, nome, datas e etiquetas.
  """
  use ChatwooterWeb, :component

  alias ChatwooterWeb.TimeAgo

  attr :contact, :map, required: true
  attr :contact_labels, :list, required: true
  attr :account_labels, :list, required: true

  # Pages/ContactDetails.vue (cabeçalho) + ContactLabels/ContactLabels.vue
  def contact_profile(assigns) do
    assigns =
      assign(assigns,
        labels_by_title: Map.new(assigns.account_labels, &{&1.title, &1}),
        available_labels:
          assigns.account_labels
          |> Enum.reject(&(&1.title in assigns.contact_labels))
          |> Enum.map(&%{value: &1.title, label: &1.title, color: &1.color})
      )

    ~H"""
    <div id="contact-profile" class="flex flex-col items-start gap-3">
      <.avatar name={@contact.name} size={72} />
      <div class="flex flex-col gap-1">
        <h3 class="text-base font-medium text-n-slate-12">{@contact.name}</h3>
        <div class="flex flex-col gap-1.5">
          <span
            :if={@contact.identifier}
            class="inline-flex items-center gap-1 text-sm text-n-slate-11"
          >
            <span class="ph-user-gear text-n-slate-10 size-4" />
            {@contact.identifier}
          </span>
          <span class="inline-flex items-center gap-1 text-sm text-n-slate-11">
            <span :if={@contact.identifier} class="ph-pulse text-n-slate-10 size-4" />
            <span title={TimeAgo.exact(@contact.inserted_at)}>
              Created {TimeAgo.long(@contact.inserted_at)}
            </span>
            •
            <span title={TimeAgo.exact(@contact.last_activity_at)}>
              Last active {TimeAgo.long(@contact.last_activity_at)}
            </span>
          </span>
        </div>
      </div>

      <div id="contact-labels" class="flex flex-wrap items-center gap-2">
        <div
          :for={title <- @contact_labels}
          id={"contact-label-#{title}"}
          class="group/label flex items-center px-1 py-1 overflow-hidden transition-all duration-300 ease-out rounded-md bg-n-alpha-2 h-7"
        >
          <div
            class="w-2 h-2 m-1 rounded-sm"
            style={"background-color: #{label_color(@labels_by_title, title)}"}
          />
          <span class="text-sm text-n-slate-12 mr-px">{title}</span>
          <div class="w-0 flex relative left-1 flex-shrink-0 overflow-hidden transition-[width] duration-300 ease-out group-hover/label:w-6">
            <.next_button
              icon="ph-x"
              color={:slate}
              variant={:faded}
              size={:xs}
              class="transition-opacity duration-200 h-7! rounded-r-md rounded-l-none w-6 bg-transparent opacity-0 group-hover/label:opacity-100"
              phx-click="remove-label"
              phx-value-title={title}
            />
          </div>
        </div>
        <div class="relative">
          <button
            type="button"
            class="flex items-center gap-1 px-2 py-1 rounded-md outline-dashed h-6 outline-1 outline-n-slate-6 hover:bg-n-alpha-2"
            phx-click={JS.toggle_attribute({"hidden", ""}, to: "#contact-labels-menu")}
          >
            <span class="ph-plus" />
            <span class="text-sm text-n-slate-11">tag</span>
          </button>
          <div phx-click-away={JS.set_attribute({"hidden", ""}, to: "#contact-labels-menu")}>
            <.dropdown_menu
              id="contact-labels-menu"
              items={@available_labels}
              event="add-label"
              class="z-[100] w-48 mt-2 left-0 top-full max-h-52"
            >
              <:item :let={item}>
                <div class="rounded-sm size-2" style={"background-color: #{item.color}"} />
              </:item>
            </.dropdown_menu>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp label_color(labels_by_title, title) do
    case labels_by_title[title] do
      %{color: color} -> color
      nil -> "currentColor"
    end
  end
end
