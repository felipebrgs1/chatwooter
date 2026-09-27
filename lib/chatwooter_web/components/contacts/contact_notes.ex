defmodule ChatwooterWeb.Components.Contacts.ContactNotes do
  @moduledoc """
  Aba Notes: `ContactsSidebar/ContactNotes.vue` + `components/ContactNoteItem.vue`.
  """
  use ChatwooterWeb, :component

  alias ChatwooterWeb.TimeAgo

  attr :notes, :list, required: true
  attr :current_scope, :map, required: true

  # ContactNotes.vue + ContactNoteItem.vue
  def contact_notes(assigns) do
    ~H"""
    <div id="contact-notes" class="flex flex-col gap-6">
      <.form
        for={%{}}
        as={:note}
        id="contact-note-form"
        phx-submit="add-note"
        phx-hook=".ResetOnSubmit"
        class="px-6"
      >
        <div class="flex flex-col gap-2 rounded-xl bg-n-alpha-black2 px-4 py-4">
          <textarea
            name="note[content]"
            rows="3"
            placeholder="Add a note"
            class="w-full p-0 text-sm bg-transparent border-0 resize-none outline-none text-n-slate-12 placeholder:text-n-slate-10"
          ></textarea>
          <div class="flex items-center justify-end gap-3">
            <.next_button
              type="submit"
              variant={:link}
              color={:blue}
              size={:sm}
              label="Save note"
              class="hover:no-underline"
            />
          </div>
        </div>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".ResetOnSubmit">
          export default {
            mounted() { this.el.addEventListener("submit", () => setTimeout(() => this.el.reset(), 0)) }
          }
        </script>
      </.form>
      <div :if={@notes != []}>
        <div
          :for={note <- @notes}
          id={"contact-note-#{note.id}"}
          class="flex flex-col gap-2 border-b border-n-strong group/note mx-6 py-4"
        >
          <div class="flex items-center justify-between gap-2">
            <div class="flex items-center gap-1.5 min-w-0">
              <.avatar name={note_author(note)} size={16} />
              <div class="min-w-0 truncate">
                <span class="inline-flex items-center gap-1 text-sm text-n-slate-11">
                  <span class="font-medium text-n-slate-12">
                    {if(note.user_id == @current_scope.user.id, do: "You", else: note_author(note))}
                  </span>
                  wrote
                  <span class="font-medium text-n-slate-12" title={TimeAgo.exact(note.created_at)}>
                    {TimeAgo.long(note.created_at)}
                  </span>
                </span>
              </div>
            </div>
            <.next_button
              variant={:faded}
              color={:ruby}
              size={:xs}
              icon="ph-trash"
              class="opacity-0 group-hover/note:opacity-100"
              phx-click="delete-note"
              phx-value-id={note.id}
            />
          </div>
          <p class="mb-0 text-sm leading-relaxed whitespace-pre-line text-n-slate-12">
            {note.content}
          </p>
        </div>
      </div>
      <p :if={@notes == []} class="px-6 py-6 text-sm leading-6 text-center text-n-slate-11">
        There are no notes associated to this contact. You can add a note by typing in the box above.
      </p>
    </div>
    """
  end

  defp note_author(%{user: %{} = user}), do: user.display_name || user.name || user.email
  defp note_author(_note), do: "Bot"
end
