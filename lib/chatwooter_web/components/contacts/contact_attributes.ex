defmodule ChatwooterWeb.Components.Contacts.ContactAttributes do
  @moduledoc """
  Aba Attributes: `ContactsSidebar/ContactCustomAttributes.vue` + `ContactCustomAttributeItem.vue`
  e os editores de `components-next/CustomAttributes/`.
  """
  use ChatwooterWeb, :component

  attr :contact, :map, required: true
  attr :attribute_definitions, :list, required: true

  # ContactCustomAttributes.vue + ContactCustomAttributeItem.vue
  def contact_attributes(assigns) do
    values = assigns.contact.custom_attributes || %{}

    {used, unused} =
      Enum.split_with(assigns.attribute_definitions, &Map.has_key?(values, &1.attribute_key))

    assigns = assign(assigns, used: used, unused: unused, values: values)

    ~H"""
    <div :if={@attribute_definitions != []} id="contact-attributes" class="flex flex-col gap-6 px-6">
      <div :if={@used != []} class="flex flex-col gap-2">
        <.attribute_item
          :for={definition <- @used}
          definition={definition}
          value={@values[definition.attribute_key]}
          used
        />
      </div>
      <div :if={@unused != []} class="flex items-center gap-3">
        <div class="flex-1 h-[1px] bg-n-slate-5" />
        <span class="text-sm font-medium text-n-slate-10">
          {length(@unused)} Unused {if(length(@unused) == 1, do: "attribute", else: "attributes")}
        </span>
        <div class="flex-1 h-[1px] bg-n-slate-5" />
      </div>
      <.searchable_list :if={@unused != []} id="contact-unused-attributes" class="flex flex-col gap-3">
        <div class="relative">
          <span class="absolute ph-magnifying-glass size-3.5 top-2.5 left-3" />
          <input
            type="search"
            data-search-input
            placeholder="Search for attributes"
            class="w-full h-8 py-2 pl-10 pr-2 text-sm outline-none border-none rounded-lg bg-n-alpha-black2 dark:bg-n-solid-1 text-n-slate-12"
          />
        </div>
        <p
          data-search-empty
          hidden
          class="flex items-center justify-start h-11 text-sm text-n-slate-11"
        >
          No attributes found
        </p>
        <div class="flex flex-col gap-2">
          <.attribute_item :for={definition <- @unused} definition={definition} value={nil} />
        </div>
      </.searchable_list>
    </div>
    <p
      :if={@attribute_definitions == []}
      class="px-6 py-10 text-sm leading-6 text-center text-n-slate-11"
    >
      There are no contact custom attributes available in this account. You can create a custom attribute in settings.
    </p>
    """
  end

  attr :definition, :map, required: true
  attr :value, :any, default: nil
  attr :used, :boolean, default: false

  defp attribute_item(assigns) do
    assigns = assign(assigns, :key, assigns.definition.attribute_key)

    ~H"""
    <div
      id={"contact-attribute-#{@key}"}
      data-used={@used}
      data-search-item
      data-search-text={@definition.attribute_display_name}
      class={[
        "grid grid-cols-[140px_1fr] group/attribute items-center w-full gap-2",
        if(@used, do: "min-h-10", else: "min-h-11")
      ]}
    >
      <div class="flex items-center justify-between truncate">
        <span class="text-sm font-medium truncate text-n-slate-12">
          {@definition.attribute_display_name}
        </span>
      </div>
      <%= case @definition.attribute_display_type do %>
        <% :checkbox -> %>
          <div class={[
            "flex items-center w-full gap-2",
            if(@used, do: "justify-start", else: "justify-end")
          ]}>
            <.next_switch
              id={"attribute-switch-#{@key}"}
              checked={@value == true}
              phx-click="toggle-attribute"
              phx-value-key={@key}
            />
            <.attribute_delete :if={@used} key={@key} />
          </div>
        <% :list -> %>
          <div class={[
            "flex items-center w-full min-w-0 gap-2",
            if(@used, do: "justify-start", else: "justify-end")
          ]}>
            <div
              class="relative flex items-center"
              phx-click-away={JS.set_attribute({"hidden", ""}, to: "#attribute-list-#{@key}")}
            >
              <span
                class={[
                  "min-w-0 text-sm",
                  if(@used,
                    do: "text-n-slate-12 truncate flex-1",
                    else:
                      "cursor-pointer text-n-slate-11 hover:text-n-slate-12 py-2 select-none font-medium"
                  )
                ]}
                phx-click={JS.toggle_attribute({"hidden", ""}, to: "#attribute-list-#{@key}")}
              >
                {@value || "Select value"}
              </span>
              <.dropdown_menu
                id={"attribute-list-#{@key}"}
                items={
                  Enum.map(@definition.attribute_values || [], &%{value: "#{@key}:#{&1}", label: &1})
                }
                selected={"#{@key}:#{@value}"}
                event="select-attribute"
                class={["w-48 mt-2 top-full", if(@used, do: "left-0", else: "right-0")]}
              />
            </div>
            <.attribute_delete :if={@used} key={@key} />
          </div>
        <% _other -> %>
          <.other_attribute definition={@definition} key={@key} value={@value} used={@used} />
      <% end %>
    </div>
    """
  end

  # OtherAttribute.vue (texto, número, link, data...)
  defp other_attribute(assigns) do
    assigns =
      assign(
        assigns,
        :input_type,
        case assigns.definition.attribute_display_type do
          type when type in [:number, :currency, :percent] -> "number"
          :date -> "date"
          :link -> "url"
          _ -> "text"
        end
      )

    ~H"""
    <div class={[
      "flex items-center w-full min-w-0 gap-2",
      if(@used, do: "justify-start", else: "justify-end")
    ]}>
      <span
        id={"attribute-value-#{@key}"}
        class={[
          "min-w-0 text-sm",
          @used && @definition.attribute_display_type != :link && "text-n-slate-12 truncate",
          @used && @definition.attribute_display_type == :link &&
            "truncate hover:text-n-brand text-n-blue-11",
          !@used &&
            "cursor-pointer text-n-slate-11 hover:text-n-slate-12 py-2 select-none font-medium"
        ]}
        phx-click={!@used && toggle_attribute_edit(@key)}
      >
        <a
          :if={@definition.attribute_display_type == :link && @value && @used}
          href={@value}
          target="_blank"
          rel="noopener noreferrer"
          class="hover:underline"
        >
          {@value}
        </a>
        <span :if={!(@definition.attribute_display_type == :link && @value && @used)}>
          {@value || "Enter value"}
        </span>
      </span>
      <div :if={@used} id={"attribute-actions-#{@key}"} class="flex items-center gap-1">
        <.next_button
          variant={:faded}
          color={:slate}
          icon="ph-pencil-simple"
          size={:xs}
          class="flex-shrink-0 opacity-0 group-hover/attribute:opacity-100"
          phx-click={toggle_attribute_edit(@key)}
        />
        <.attribute_delete key={@key} />
      </div>
      <.form
        for={%{}}
        as={:attribute}
        id={"attribute-form-#{@key}"}
        phx-submit="save-attribute"
        class="flex items-center w-full"
        hidden
      >
        <input type="hidden" name="key" value={@key} />
        <.next_input
          name="attribute[value]"
          value={@value}
          type={@input_type}
          placeholder="Enter value"
          size={:sm}
          class="w-full"
          input_class="h-8 rounded-r-none"
        />
        <.next_button type="submit" icon="ph-check" size={:sm} class="flex-shrink-0 rounded-l-none" />
      </.form>
    </div>
    """
  end

  defp toggle_attribute_edit(key) do
    JS.toggle_attribute({"hidden", ""}, to: "#attribute-form-#{key}")
    |> JS.toggle_attribute({"hidden", ""}, to: "#attribute-value-#{key}")
    |> JS.focus(to: "#attribute-form-#{key} input[name='attribute[value]']")
  end

  attr :key, :string, required: true

  defp attribute_delete(assigns) do
    ~H"""
    <.next_button
      variant={:faded}
      color={:ruby}
      icon="ph-trash"
      size={:xs}
      class="flex-shrink-0 opacity-0 group-hover/attribute:opacity-100"
      phx-click="delete-attribute"
      phx-value-key={@key}
    />
    """
  end
end
