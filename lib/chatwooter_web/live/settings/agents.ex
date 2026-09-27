defmodule ChatwooterWeb.SettingsLive.Agents do
  @moduledoc "Settings → Agents: convidar, editar papel/disponibilidade e remover membros."
  use ChatwooterWeb, :live_view

  alias Chatwooter.Accounts
  alias Chatwooter.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    account = socket.assigns.current_scope.user |> Accounts.list_user_accounts() |> List.first()
    {:ok, socket |> assign(:account, account) |> assign_page(account)}
  end

  defp assign_page(socket, nil), do: socket

  defp assign_page(socket, account) do
    socket
    |> assign(:members, Accounts.list_account_users(account))
    |> assign(
      :invite_form,
      to_form(%{"name" => "", "email" => "", "role" => "agent"}, as: "invite")
    )
    |> assign(:editing_agent, nil)
    |> assign(:agent_form, nil)
  end

  @impl true
  def handle_event("invite", %{"invite" => params}, socket) do
    attrs = %{
      "name" => String.trim(params["name"] || ""),
      "email" => String.trim(params["email"] || ""),
      "role" => params["role"] || "agent"
    }

    case Accounts.create_agent(socket.assigns.account, attrs) do
      {:ok, user} ->
        Accounts.deliver_login_instructions(user, &url(~p"/app/login/#{&1}"))

        {:noreply,
         socket
         |> assign(:members, Accounts.list_account_users(socket.assigns.account))
         |> assign(
           :invite_form,
           to_form(%{"name" => "", "email" => "", "role" => "agent"}, as: "invite")
         )
         |> put_flash(:info, "Invitation sent to #{user.email}.")}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "Could not invite (invalid data or already a member?).")}
    end
  end

  def handle_event("change-role", %{"role" => role, "id" => user_id}, socket) do
    user = Accounts.get_user!(String.to_integer(user_id))

    case Accounts.update_agent(socket.assigns.account, user, %{
           role: role,
           email: user.email,
           name: user.name || ""
         }) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:members, Accounts.list_account_users(socket.assigns.account))
         |> put_flash(:info, "Role updated.")}

      {:error, :last_admin} ->
        {:noreply, put_flash(socket, :error, "The account needs at least one admin.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update role.")}
    end
  end

  def handle_event("edit-agent", %{"id" => user_id}, socket) do
    user = Accounts.get_user!(String.to_integer(user_id))
    membership = Enum.find(socket.assigns.members, &(&1.user_id == user.id))

    params = %{
      "name" => user.name || "",
      "role" => to_string(membership.role),
      "availability" => to_string(membership.availability),
      "auto_offline" => membership.auto_offline
    }

    {:noreply,
     socket
     |> assign(:editing_agent, user)
     |> assign(:agent_form, to_form(params, as: "agent"))}
  end

  def handle_event("close-agent-modal", _params, socket) do
    {:noreply, socket |> assign(:editing_agent, nil) |> assign(:agent_form, nil)}
  end

  def handle_event(
        "validate-agent",
        %{"agent" => params},
        %{assigns: %{editing_agent: user}} = socket
      ) do
    changeset =
      User.agent_changeset(user, Map.put(params, "email", user.email), validate_unique: false)

    {:noreply, assign(socket, :agent_form, to_form(changeset, as: "agent", action: :validate))}
  end

  def handle_event("save-agent", %{"agent" => params}, socket) do
    user = socket.assigns.editing_agent
    attrs = Map.put(params, "email", user.email)

    case Accounts.update_agent(socket.assigns.account, user, attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:members, Accounts.list_account_users(socket.assigns.account))
         |> assign(:editing_agent, nil)
         |> assign(:agent_form, nil)
         |> put_flash(:info, "Agent updated.")}

      {:error, :last_admin} ->
        {:noreply, put_flash(socket, :error, "The account needs at least one admin.")}

      {:error, changeset} ->
        {:noreply,
         assign(socket, :agent_form, to_form(changeset, as: "agent", action: :validate))}
    end
  end

  def handle_event("send-login-link", %{"id" => user_id}, socket) do
    user = Accounts.get_user!(String.to_integer(user_id))
    Accounts.deliver_login_instructions(user, &url(~p"/app/login/#{&1}"))

    {:noreply, put_flash(socket, :info, "Login link sent to #{user.email}.")}
  end

  def handle_event(
        "change-availability",
        %{"availability" => availability, "id" => user_id},
        socket
      ) do
    user = Accounts.get_user!(String.to_integer(user_id))

    case Accounts.update_agent(socket.assigns.account, user, %{
           availability: availability,
           email: user.email,
           name: user.name || ""
         }) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:members, Accounts.list_account_users(socket.assigns.account))
         |> put_flash(:info, "Availability updated.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update availability.")}
    end
  end

  def handle_event("remove-member", %{"id" => user_id}, socket) do
    current_id = socket.assigns.current_scope.user.id

    if String.to_integer(user_id) == current_id do
      {:noreply, put_flash(socket, :error, "You cannot remove yourself.")}
    else
      user = Accounts.get_user!(String.to_integer(user_id))

      case Accounts.remove_member(socket.assigns.account, user) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:members, Accounts.list_account_users(socket.assigns.account))
           |> put_flash(:info, "Member removed.")}

        {:error, :last_admin} ->
          {:noreply, put_flash(socket, :error, "The account needs at least one admin.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not remove member.")}
      end
    end
  end
end
