defmodule ChatwooterWeb.Components.Next.Input do
  @moduledoc "Port de `components-next/input/Input.vue`."
  use ChatwooterWeb, :base_component

  @doc """
  `components-next/input/Input.vue`. Aceita um `Phoenix.HTML.FormField`:

      <.next_input field={@form[:email]} placeholder="Enter the email address" size={:sm} />
  """
  attr :field, Phoenix.HTML.FormField, default: nil
  attr :id, :string, default: nil
  attr :name, :string, default: nil
  attr :value, :any, default: nil
  attr :type, :string, default: "text"
  attr :label, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :size, :atom, default: :md, values: [:sm, :md]
  attr :message, :string, default: nil
  attr :message_type, :atom, default: :info, values: [:info, :error, :success]
  attr :input_class, :any, default: nil
  attr :class, :any, default: nil

  attr :rest, :global,
    include: ~w(autocomplete disabled form min max phx-debounce autofocus required)

  def next_input(assigns) do
    assigns =
      case assigns.field do
        %Phoenix.HTML.FormField{} = field ->
          errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

          assigns
          |> assign(:id, assigns.id || field.id)
          |> assign(:name, assigns.name || field.name)
          |> assign(:value, assigns.value || field.value)
          |> assign(:message, assigns.message || error_message(errors))
          |> assign(:message_type, if(errors != [], do: :error, else: assigns.message_type))

        nil ->
          assigns
      end

    ~H"""
    <div class={["relative flex flex-col min-w-0 gap-1", @class]}>
      <label :if={@label} for={@id} class="mb-0.5 text-heading-3 text-n-slate-12">{@label}</label>
      <input
        id={@id}
        name={@name}
        type={@type}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        placeholder={@placeholder}
        class={[
          "block w-full text-sm mb-0! outline outline-1 border-none border-0 outline-offset-[-1px] rounded-lg bg-n-alpha-black2 text-ellipsis placeholder:text-n-slate-10 disabled:cursor-not-allowed disabled:opacity-50 text-n-slate-12 transition-all duration-500 ease-in-out [appearance:textfield]",
          if(@message_type == :error,
            do: "outline-n-ruby-8 hover:outline-n-ruby-9",
            else: "outline-n-weak hover:outline-n-slate-6 focus:outline-n-brand"
          ),
          if(@size == :sm, do: "h-8 px-3! py-2!", else: "h-10 px-3! py-2.5!"),
          @input_class
        ]}
        {@rest}
      />
      <p
        :if={@message}
        class={[
          "min-w-0 mt-1 mb-0 text-label-small truncate transition-all duration-500 ease-in-out",
          case @message_type do
            :error -> "text-n-ruby-9"
            :success -> "text-n-teal-10"
            :info -> "text-n-slate-11"
          end
        ]}
      >
        {@message}
      </p>
    </div>
    """
  end

  defp error_message([]), do: nil

  defp error_message([{msg, opts} | _]) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
