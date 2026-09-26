defmodule ChatwooterWeb.UserLive.Registration do
  use ChatwooterWeb, :live_view

  alias Chatwooter.Accounts
  alias Chatwooter.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <main class="mx-auto max-w-sm space-y-6 px-6 py-12">
      <div>
        <h2 class="text-2xl font-bold tracking-tight text-slate-900">Register for an account</h2>
        <p class="mt-2 text-sm text-slate-600">
          Already registered?
          <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
            Log in
          </.link>
          to your account now.
        </p>
      </div>

      <Layouts.flash_group flash={@flash} />

      <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
        <.input
          field={@form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          spellcheck="false"
          required
          phx-mounted={JS.focus()}
        />

        <.button phx-disable-with="Creating account..." variant="primary" class="w-full">
          Create an account
        </.button>
      </.form>
    </main>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: ChatwooterWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
