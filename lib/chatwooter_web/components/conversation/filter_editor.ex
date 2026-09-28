defmodule ChatwooterWeb.Components.Conversation.FilterEditor do
  @moduledoc "Port of components-next/filter/ConversationFilter.vue, rendered in the header's `filter_popover` slot."
  use ChatwooterWeb, :component
  import ChatwooterWeb.Components.Conversation.FilterCondition

  @attributes [
    {"status", "Status"},
    {"priority", "Priority"},
    {"assignee_id", "Assignee name"},
    {"inbox_id", "Inbox name"},
    {"team_id", "Team name"},
    {"contact_id", "Contact"},
    {"display_id", "Conversation identifier"},
    {"campaign_id", "Campaign name"},
    {"labels", "Labels"},
    {"created_at", "Created at"},
    {"last_activity_at", "Last activity"},
    {"browser_language", "Browser language"},
    {"referer", "Referer link"}
  ]
  attr :folder, :any, default: nil
  attr :form, Phoenix.HTML.Form, required: true
  attr :rows, :list, required: true
  attr :error, :string, default: nil
  attr :custom_definitions, :list, default: []
  attr :labels, :list, default: []
  attr :value_options, :map, default: %{}
  attr :contact_options, :map, default: %{}

  def conversation_filter_editor(assigns) do
    definitions =
      assigns.custom_definitions
      |> Enum.reject(&List.keymember?(@attributes, &1.attribute_key, 0))

    standard = Enum.reject(@attributes, fn {key, _} -> key in ~w(browser_language referer) end)
    additional = Enum.filter(@attributes, fn {key, _} -> key in ~w(browser_language referer) end)

    custom =
      Enum.map(
        definitions,
        &%{
          value: &1.attribute_key,
          label: &1.attribute_display_name,
          icon: custom_icon(&1.attribute_display_type)
        }
      )

    attributes =
      group("standard", "Standard filters", Enum.map(standard, &attribute_option/1)) ++
        group("additional", "Additional filters", Enum.map(additional, &attribute_option/1)) ++
        group("customAttributes", "Custom attributes", custom)

    assigns = assign(assigns, attributes: attributes, custom_definitions: definitions)

    ~H"""
    <div
      id="conversation-filter-editor"
      phx-hook=".FilterTimezone"
      class="z-40 w-[min(34rem,calc(100vw-2rem))] lg:w-[750px] overflow-visible border border-n-weak bg-n-alpha-3 backdrop-blur-[100px] shadow-lg rounded-xl p-6 grid gap-6"
    >
      <.form
        for={@form}
        id="conversation-filter-form"
        phx-change="filter:change"
        phx-submit="filter:apply"
        class="grid gap-6"
      >
        <h3 class="text-base font-medium leading-6 text-n-slate-12">
          {if(@folder, do: "Edit Folder", else: "Filter conversations")}
        </h3>
        <div :if={@folder} class="border-b border-n-weak pb-6">
          <.next_input field={@form[:name]} label="Folder Name" placeholder="Enter value" />
        </div>
        <ul class="grid gap-4 list-none min-w-0">
          <.conversation_filter_condition
            :for={{row, i} <- Enum.with_index(@rows)}
            row={row}
            previous={Enum.at(@rows, i - 1)}
            index={i}
            attributes={@attributes}
            labels={@labels}
            value_options={@value_options}
            contact_options={@contact_options}
            definition={
              Enum.find(@custom_definitions, &(&1.attribute_key == row[:attribute_key].value))
            }
          />
        </ul>
        <p :if={@error} id="conversation-filter-error" role="alert" class="text-sm text-n-ruby-11">
          {@error}
        </p>
        <div class="flex gap-2 justify-between">
          <.next_button
            id="add-filter-condition"
            label="Add filter"
            variant={:ghost}
            size={:sm}
            phx-click="filter:add"
          />
          <div class="flex gap-2">
            <.next_button
              id="clear-conversation-filters"
              label="Clear filters"
              variant={:faded}
              color={:slate}
              size={:sm}
              phx-click="filter:clear"
            />
            <.next_button
              id="apply-conversation-filters"
              label={if(@folder, do: "Update folder", else: "Apply filters")}
              type="submit"
              size={:sm}
            />
          </div>
        </div>
      </.form>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".FilterTimezone">
        export default {
          fillTimezone() {
            this.el.querySelectorAll('[data-filter-timezone]').forEach(input => {
              if (!input.value) input.value = Intl.DateTimeFormat().resolvedOptions().timeZone
            })
          },
          mounted() { this.fillTimezone() },
          updated() { this.fillTimezone() }
        }
      </script>
    </div>
    """
  end

  defp group(_key, _label, []), do: []
  defp group(key, label, options), do: [%{value: key, label: label, disabled: true} | options]

  # The original uses Lucide; the project standard requires the corresponding Phosphor icons.
  defp attribute_option({key, label}) do
    icon = %{
      "status" => "ph-record",
      "priority" => "ph-cell-signal-high",
      "assignee_id" => "ph-user",
      "inbox_id" => "ph-tray",
      "team_id" => "ph-users",
      "contact_id" => "ph-address-book",
      "display_id" => "ph-hash",
      "campaign_id" => "ph-megaphone",
      "browser_language" => "ph-globe",
      "referer" => "ph-link",
      "labels" => "ph-tag",
      "created_at" => "ph-calendar",
      "last_activity_at" => "ph-pulse"
    }

    %{value: key, label: label, icon: Map.fetch!(icon, key)}
  end

  defp custom_icon(type) do
    Map.get(
      %{
        text: "ph-text-t",
        number: "ph-hash",
        link: "ph-link",
        date: "ph-calendar",
        list: "ph-list",
        checkbox: "ph-check-square"
      },
      type,
      "ph-tag"
    )
  end
end
