defmodule ChatwooterWeb.SettingsLive.Profile.ConfirmEmail.Show do
  @moduledoc "Aplica o link de troca de e-mail e volta para Settings → Profile."
  use ChatwooterWeb, :live_view

  alias Chatwooter.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/app/settings/profile")}
  end

  # só redireciona: o mount sempre navega de volta, não há markup
  @impl true
  def render(assigns), do: ~H""
end
