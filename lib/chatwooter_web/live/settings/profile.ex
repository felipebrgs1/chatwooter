defmodule ChatwooterWeb.SettingsLive.Profile do
  @moduledoc "Settings → Profile: e-mail e senha do usuário (exigem sudo mode)."
  use ChatwooterWeb, :live_view

  alias Chatwooter.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:current_email, user.email)
     |> assign(
       :email_form,
       to_form(Accounts.change_user_email(user, %{}, validate_unique: false))
     )
     |> assign(
       :password_form,
       to_form(Accounts.change_user_password(user, %{}, hash_password: false))
     )
     |> assign(:trigger_submit, false)}
  end

  @impl true
  def handle_event("validate-profile-email", %{"user" => params}, socket) do
    form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: form)}
  end

  def handle_event("save-profile-email", %{"user" => params}, socket) do
    user = socket.assigns.current_scope.user

    if Accounts.sudo_mode?(user, -10) do
      case Accounts.change_user_email(user, params) do
        %{valid?: true} = changeset ->
          Accounts.deliver_user_update_email_instructions(
            Ecto.Changeset.apply_action!(changeset, :insert),
            user.email,
            &url(~p"/app/settings/profile/confirm-email/#{&1}")
          )

          {:noreply,
           socket |> put_flash(:info, "A link to confirm your email change has been sent.")}

        changeset ->
          {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
      end
    else
      {:noreply, require_sudo(socket)}
    end
  end

  def handle_event("validate-profile-password", %{"user" => params}, socket) do
    form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: form)}
  end

  def handle_event("save-profile-password", %{"user" => params}, socket) do
    user = socket.assigns.current_scope.user

    if Accounts.sudo_mode?(user, -10) do
      case Accounts.change_user_password(user, params) do
        %{valid?: true} = changeset ->
          {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

        changeset ->
          {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
      end
    else
      {:noreply, require_sudo(socket)}
    end
  end

  defp require_sudo(socket) do
    socket
    |> put_flash(:error, "You must re-authenticate to access this page.")
    |> push_navigate(to: ~p"/app/login")
  end
end
