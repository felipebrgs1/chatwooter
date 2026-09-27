defmodule ChatwooterWeb.Components.Contacts.ContactMedia do
  @moduledoc """
  Aba Media: `ContactsSidebar/ContactMedia.vue` → `SharedAttachments/Media.vue` + `Files.vue`.
  """
  use ChatwooterWeb, :component

  alias ChatwooterWeb.TimeAgo

  # ContactMedia.vue → MEDIA_PEEK_LIMIT / FILES_PEEK_LIMIT
  @media_peek 12
  @files_peek 6

  attr :attachments, :list, required: true

  # ContactMedia.vue → SharedAttachments/Media.vue + Files.vue
  def contact_media(assigns) do
    {media, files} = Enum.split_with(assigns.attachments, &(&1.file_type in [:image, :video]))

    assigns =
      assign(assigns,
        media: media,
        files: files,
        media_peek: @media_peek,
        files_peek: @files_peek
      )

    ~H"""
    <div id="contact-media" class="px-6">
      <p :if={@attachments == []} class="p-3 text-sm text-center text-n-slate-11">
        No attachments yet
      </p>
      <div :if={@attachments != []} class="flex flex-col gap-5">
        <section :if={@media != []} id="contact-media-grid" class="group/peek flex flex-col gap-2.5">
          <.shared_heading
            title="Media"
            count={length(@media)}
            peek={length(@media) > @media_peek}
            target="#contact-media-grid"
          />
          <div class="grid grid-cols-3 gap-2">
            <a
              :for={{attachment, index} <- Enum.with_index(@media)}
              href={attachment.url}
              target="_blank"
              rel="noopener noreferrer"
              class={[
                "relative w-full overflow-hidden transition-all duration-200 rounded-lg cursor-pointer aspect-square bg-n-slate-3 shadow-sm hover:shadow-md hover:-translate-y-px group",
                index >= @media_peek && "hidden group-data-[show-all]/peek:block"
              ]}
            >
              <img
                :if={attachment.file_type == :image}
                src={attachment.url}
                loading="lazy"
                class="object-cover w-full h-full transition-transform duration-300 group-hover:scale-110"
              />
              <video
                :if={attachment.file_type == :video}
                src={"#{attachment.url}#t=0.1"}
                preload="metadata"
                muted
                playsinline
                class="object-cover w-full h-full pointer-events-none"
              />
            </a>
          </div>
        </section>
        <section :if={@files != []} id="contact-files" class="group/peek flex flex-col gap-2.5">
          <.shared_heading
            title="Files"
            count={length(@files)}
            peek={length(@files) > @files_peek}
            target="#contact-files"
          />
          <ul class="flex flex-col gap-0.5">
            <li
              :for={{attachment, index} <- Enum.with_index(@files)}
              class={index >= @files_peek && "hidden group-data-[show-all]/peek:list-item"}
            >
              <a
                href={attachment.url}
                target="_blank"
                rel="noopener noreferrer"
                class="flex items-center gap-3 px-2 py-2 transition-colors rounded-lg cursor-pointer hover:bg-n-slate-3"
              >
                <div class="flex items-center justify-center rounded-lg size-9 shrink-0 bg-linear-to-br from-n-slate-3 to-n-slate-4 ring-1 ring-inset ring-n-slate-4/40">
                  <span class="ph-file size-4 text-n-slate-11" />
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium truncate text-n-slate-12 mb-1">
                    {file_name(attachment)}
                  </p>
                  <p class="text-xs text-n-slate-11 mb-0">{TimeAgo.long(attachment.created_at)}</p>
                </div>
              </a>
            </li>
          </ul>
        </section>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :peek, :boolean, default: false
  attr :target, :string, required: true

  defp shared_heading(assigns) do
    ~H"""
    <header class="flex items-center justify-between px-0.5">
      <h4 class="text-xs font-semibold tracking-wider uppercase text-n-slate-11 mb-0">
        {@title}
        <span class="ms-1 font-medium tracking-normal normal-case text-n-slate-10">{@count}</span>
      </h4>
      <.next_button
        :if={@peek}
        variant={:ghost}
        color={:slate}
        size={:xs}
        trailing_icon
        icon="ph-caret-right"
        label="View all"
        phx-click={JS.toggle_attribute({"data-show-all", ""}, to: @target)}
      />
    </header>
    """
  end

  defp file_name(%{key: key}) when is_binary(key), do: Path.basename(key)

  defp file_name(%{url: url}) when is_binary(url),
    do: url |> URI.parse() |> Map.get(:path, "") |> Path.basename()

  defp file_name(_attachment), do: "Untitled file"
end
