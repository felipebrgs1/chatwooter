defmodule ChatwooterWeb.Components.Contacts.ContactForm do
  @moduledoc """
  Port de `ContactsForm/ContactsForm.vue` (detalhe) com `PhoneNumberInput.vue`.
  """
  use ChatwooterWeb, :component

  alias ChatwooterWeb.Countries

  # ContactsForm.vue → SOCIAL_CONFIG (ícones remixicon traduzidos para Phosphor)
  @socials [
    {"linkedin", "ph-linkedin-logo", "Add LinkedIn"},
    {"facebook", "ph-facebook-logo", "Add Facebook"},
    {"instagram", "ph-instagram-logo", "Add Instagram"},
    {"whatsapp", "ph-whatsapp-logo", "Add WhatsApp"},
    {"telegram", "ph-telegram-logo", "Add Telegram"},
    {"tiktok", "ph-tiktok-logo", "Add TikTok"},
    {"twitter", "ph-twitter-logo", "Add Twitter"},
    {"github", "ph-github-logo", "Add Github"}
  ]

  @doc "Chaves de redes sociais do formulário (`additional_attributes.social_profiles`)."
  def social_keys, do: Enum.map(@socials, &elem(&1, 0))

  attr :form, Phoenix.HTML.Form, required: true
  attr :form_params, :map, required: true
  attr :country_options, :list, required: true
  attr :companies, :list, required: true

  # ContactsForm.vue (is-details-view) + botão "Update contact"
  def contact_form(assigns) do
    assigns =
      assign(assigns,
        socials: @socials,
        phone_country: Countries.get(assigns.form_params["phone_country"])
      )

    ~H"""
    <.form
      for={@form}
      id="contact-form"
      phx-change="validate"
      phx-submit="save"
      class="flex flex-col items-start gap-6 w-full"
    >
      <div class="flex flex-col gap-6 w-full">
        <div class="flex flex-col items-start gap-2">
          <span class="py-1 text-sm font-medium text-n-slate-12">Edit contact details</span>
          <div class="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
            <.next_input
              field={@form[:first_name]}
              placeholder="Enter the first name"
              input_class="h-8 pt-1! pb-1!"
            />
            <.next_input
              field={@form[:last_name]}
              placeholder="Enter the last name"
              input_class="h-8 pt-1! pb-1!"
            />
            <.next_input
              field={@form[:email]}
              type="email"
              placeholder="Enter the email address"
              input_class="h-8 pt-1! pb-1!"
            />
            <.phone_input form={@form} country={@phone_country} />
            <.next_input
              field={@form[:city]}
              placeholder="Enter the city name"
              input_class="h-8 pt-1! pb-1!"
            />
            <.combobox
              id="contact-country"
              options={@country_options}
              value={@form_params["country_code"]}
              event="select-country"
              placeholder="Select country"
            />
            <.next_input
              field={@form[:description]}
              placeholder="Enter the bio"
              input_class="h-8 pt-1! pb-1!"
            />
            <.combobox
              id="contact-company"
              options={Enum.map(@companies, &%{value: to_string(&1.id), label: &1.name})}
              value={@form_params["company_id"]}
              event="select-company"
              placeholder="Select company"
              search_placeholder="Search companies..."
            />
          </div>
        </div>
        <div class="flex flex-col items-start gap-2">
          <span class="py-1 text-sm font-medium text-n-slate-12">Edit social links</span>
          <div class="flex flex-wrap gap-2">
            <div
              :for={{key, icon, placeholder} <- @socials}
              class="flex items-center h-8 gap-2 px-2 rounded-lg bg-n-alpha-2 dark:bg-n-solid-2"
            >
              <span class={[icon, "flex-shrink-0 text-n-slate-11 size-4"]} />
              <input
                name={"contact[social][#{key}]"}
                value={@form_params["social"][key]}
                placeholder={placeholder}
                size={String.length(placeholder)}
                class="w-auto min-w-[100px] text-sm bg-transparent outline-none text-n-slate-12 placeholder:text-n-slate-10"
              />
            </div>
          </div>
        </div>
      </div>
      <.next_button type="submit" label="Update contact" size={:sm} />
    </.form>
    """
  end

  # PhoneNumberInput.vue: DDI (bandeira) + número local
  defp phone_input(assigns) do
    assigns =
      assign(
        assigns,
        :options,
        Enum.map(
          Countries.all(),
          &%{value: &1.id, label: "#{&1.emoji} #{&1.name} (#{&1.dial_code})"}
        )
      )

    ~H"""
    <div
      class="relative flex items-center h-8 transition-all duration-500 ease-in-out outline outline-1 outline-offset-[-1px] rounded-lg bg-n-alpha-black2 outline-n-weak hover:outline-n-slate-6 focus-within:outline-n-brand"
      phx-click-away={JS.set_attribute({"hidden", ""}, to: "#contact-phone-country-menu")}
    >
      <input type="hidden" name="contact[phone_country]" value={@form[:phone_country].value} />
      <div id="contact-phone-country" class="flex items-center flex-shrink-0">
        <.next_button
          color={:slate}
          size={:sm}
          icon={if(@country, do: "ph-caret-down", else: "ph-globe")}
          trailing_icon
          label={@country && @country.emoji}
          class="h-[1.875rem]! ml-px px-2! outline-0 outline-none! rounded-lg! border-0 rounded-r-none!"
          phx-click={
            JS.toggle_attribute({"hidden", ""}, to: "#contact-phone-country-menu")
            |> JS.focus(to: "#contact-phone-country-menu input")
          }
        />
        <span :if={@country} class="text-sm text-n-slate-11 pl-1">{@country.dial_code}</span>
      </div>
      <input
        id={@form[:phone_local].id}
        name={@form[:phone_local].name}
        value={@form[:phone_local].value}
        type="tel"
        placeholder="Enter the phone number"
        class="block w-full h-8 py-0.5 pl-1 pr-3 text-sm bg-transparent border-0 outline-none text-n-slate-12 placeholder:text-n-slate-10"
      />
      <.dropdown_menu
        id="contact-phone-country-menu"
        items={@options}
        selected={@country && @country.id}
        event="select-phone-country"
        class="z-[100] w-64 mt-2 left-0 top-full max-h-52"
      />
    </div>
    """
  end
end
