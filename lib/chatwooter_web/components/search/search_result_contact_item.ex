defmodule ChatwooterWeb.Components.Search.SearchResultContactItem do
  @moduledoc """
  Contato encontrado — port de `modules/search/components/SearchResultContactItem.vue`
  (o `CardLayout` row entra inline). A bandeira do país usa o emoji da lista de
  países em vez do componente `Flag`.
  """
  use ChatwooterWeb, :component

  alias ChatwooterWeb.{Countries, TimeAgo}

  attr :contact, :map, required: true

  def search_result_contact_item(assigns) do
    contact = assigns.contact

    assigns =
      assigns
      |> assign(:country, country_details(contact.additional_attributes || %{}))
      |> assign(:email, blank_to_nil(contact.email))
      |> assign(:phone, blank_to_nil(contact.phone_number))

    ~H"""
    <.link
      id={"search-contact-#{@contact.id}"}
      navigate={~p"/app/contacts/#{@contact.id}"}
      class="flex flex-col w-full outline-1 outline outline-n-container -outline-offset-1 group/cardLayout rounded-xl bg-n-solid-2 hover:bg-n-slate-2 dark:hover:bg-n-solid-3"
    >
      <div class="flex w-full gap-3 flex-row justify-start items-start px-4 py-3">
        <.avatar
          name={@contact.name}
          size={24}
          class="mt-1 flex-shrink-0 [&>[role=img]]:rounded-full"
        />
        <div class="min-w-0 flex flex-col items-start gap-1.5 w-full">
          <div class="flex items-center min-w-0 justify-between gap-2 w-full">
            <h5 class="text-sm font-medium truncate min-w-0 text-n-slate-12 py-1">
              {@contact.name}
            </h5>
            <span
              :if={@contact.last_activity_at}
              title={TimeAgo.exact(@contact.last_activity_at)}
              class="text-sm font-normal min-w-0 truncate text-n-slate-11"
            >
              updated {TimeAgo.long(@contact.last_activity_at)}
            </span>
          </div>
          <div class="grid items-center gap-3 m-0 text-sm overflow-hidden min-w-0 grid-cols-[minmax(0,max-content)_auto_minmax(0,max-content)_auto_minmax(0,max-content)]">
            <span :if={@email} class="truncate text-n-slate-11 min-w-0" title={@email}>
              {@email}
            </span>
            <div :if={@email && @phone} class="w-px h-3 bg-n-slate-6 rounded" />
            <span :if={@phone} title={@phone} class="truncate text-n-slate-11 min-w-0">
              {@phone}
            </span>
            <div :if={(@email || @phone) && @country} class="w-px h-3 bg-n-slate-6 rounded" />
            <span :if={@country} class="truncate text-n-slate-11 flex items-center gap-1 min-w-0">
              <span class="shrink-0 text-xs">{@country.emoji}</span>
              <span class="truncate min-w-0">{@country.location}</span>
            </span>
          </div>
        </div>
      </div>
    </.link>
    """
  end

  # countryDetails / formattedLocation do .vue
  defp country_details(attrs) do
    country = Countries.get(attrs["country"]) || Countries.get(attrs["country_code"])

    if country do
      city = if attrs["city"] not in [nil, ""], do: "#{attrs["city"]},"

      %{
        emoji: country.emoji,
        location: Enum.join(Enum.reject([city, country.name], &is_nil/1), " ")
      }
    end
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value
end
