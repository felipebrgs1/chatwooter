defmodule ChatwooterWeb.LoginLive.Index do
  use ChatwooterWeb, :live_view

  @impl true
  # Logged-in users go straight to the dashboard — except the sudo
  # re-auth flow, which arrives carrying this exact error flash
  # (see UserAuth.on_mount(:require_sudo_mode, ...)).
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}, flash: flash}} = socket)
      when not is_nil(user) do
    if Phoenix.Flash.get(flash, :error) == "You must re-authenticate to access this page." do
      {:ok, mount_form(socket)}
    else
      {:ok, push_navigate(socket, to: ~p"/app")}
    end
  end

  def mount(_params, _session, socket) do
    {:ok, mount_form(socket)}
  end

  defp mount_form(socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email, "remember_me" => "true"}, as: "user")

    assign(socket, form: form, trigger_submit: false)
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
