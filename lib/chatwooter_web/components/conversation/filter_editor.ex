defmodule ChatwooterWeb.Components.Conversation.FilterEditor do
  @moduledoc "Port of components-next/filter/ConversationFilter.vue and SaveCustomView.vue; deletion from customviews/DeleteCustomViews.vue."
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
  attr :mode, :atom, default: nil
  attr :folder, :any, default: nil
  attr :form, Phoenix.HTML.Form, required: true
  attr :rows, :list, required: true
  attr :folder_form, Phoenix.HTML.Form, required: true
  attr :error, :string, default: nil

  def conversation_filter_editor(assigns) do
    assigns = assign(assigns, attributes: @attributes)

    ~H"""
    <div
      :if={@mode}
      id="conversation-filter-overlay"
      class="fixed inset-0 z-50 bg-n-alpha-black1"
      phx-click-away="filter:close"
    >
      <div
        id="conversation-filter-editor"
        phx-hook=".FilterTimezone"
        class="absolute top-20 left-4 md:left-56 z-40 w-[min(34rem,calc(100vw-2rem))] lg:w-[750px] max-h-[calc(100vh-6rem)] overflow-y-auto border border-n-weak bg-n-alpha-3 backdrop-blur-[100px] shadow-lg rounded-xl p-6 grid gap-6 text-n-slate-12"
      >
        <.form
          :if={@mode == :edit}
          for={@form}
          id="conversation-filter-form"
          phx-change="filter:change"
          phx-submit="filter:apply"
          class="grid gap-6"
        >
          <h3 class="text-base font-medium leading-6">
            {if(@folder, do: "Edit Folder", else: "Filter conversations")}
          </h3>
          <.next_input
            :if={@folder}
            field={@form[:name]}
            label="Folder Name"
            placeholder="Enter value"
          />
          <%!-- Native selects and comma-separated values are temporary until the searchable multi-value ConditionRow picker is ported. --%>
          <ul class="grid gap-4 list-none min-w-0">
            <.conversation_filter_condition
              :for={{row, i} <- Enum.with_index(@rows)}
              row={row}
              previous={Enum.at(@rows, i - 1)}
              index={i}
              attributes={@attributes}
            />
          </ul>
          <p :if={@error} id="conversation-filter-error" role="alert" class="text-sm text-n-ruby-9">
            {@error}
          </p>
          <div class="flex gap-2 justify-between flex-wrap">
            <.next_button
              id="add-filter-condition"
              label="Add filter"
              variant={:ghost}
              size={:sm}
              phx-click="filter:add"
            />
            <div class="flex gap-2">
              <.next_button
                label="Cancel"
                variant={:faded}
                color={:slate}
                size={:sm}
                phx-click="filter:close"
              />
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
        <.form
          :if={@mode == :save}
          for={@folder_form}
          id="save-filter-form"
          phx-submit="filter:save"
          class="grid gap-6"
        >
          <h3 class="text-base font-medium leading-6">Do you want to save this filter?</h3>
          <.next_input field={@folder_form[:name]} placeholder="Name your filter to refer it later." />
          <p :if={@error} role="alert" class="text-sm text-n-ruby-9">{@error}</p>
          <div class="flex justify-end gap-2">
            <.next_button
              label="Cancel"
              variant={:faded}
              color={:slate}
              size={:sm}
              phx-click="filter:close"
            />
            <.next_button id="confirm-save-filter" label="Save filter" type="submit" size={:sm} />
          </div>
        </.form>
        <div :if={@mode == :delete && @folder} id="delete-filter-confirmation" class="grid gap-6">
          <h3 class="text-base font-medium leading-6">Confirm deletion</h3>
          <p>Are you sure to delete the filter {@folder.name}?</p>
          <div class="flex justify-end gap-2">
            <.next_button
              label="No, keep it"
              variant={:faded}
              color={:slate}
              size={:sm}
              phx-click="filter:close"
            />
            <.next_button
              id="confirm-delete-filter"
              label="Yes, delete"
              color={:ruby}
              size={:sm}
              phx-click="filter:delete"
            />
          </div>
        </div>
      </div>
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
end
