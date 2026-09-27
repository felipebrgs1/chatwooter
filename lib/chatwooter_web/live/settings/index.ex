defmodule ChatwooterWeb.SettingsLive.Index do
  @moduledoc "Settings → General (nome e preferências da conta)."
  use ChatwooterWeb, :live_view

  alias Chatwooter.Accounts
  alias Chatwooter.Accounts.Account

  @impl true
  def mount(_params, _session, socket) do
    account = socket.assigns.current_scope.user |> Accounts.list_user_accounts() |> List.first()
    {:ok, socket |> assign(:account, account) |> assign_page(account)}
  end

  defp assign_page(socket, nil), do: socket

  defp assign_page(socket, account) do
    assign(socket, :account_form, to_form(Account.changeset(account, %{}), as: "account"))
  end

  @impl true
  def handle_event("save-account", %{"account" => params}, socket) do
    case Accounts.update_account(socket.assigns.account, params) do
      {:ok, account} ->
        {:noreply,
         socket
         |> assign(:account, account)
         |> assign(:account_form, to_form(Account.changeset(account, %{}), as: "account"))
         |> put_flash(:info, "Account updated.")}

      {:error, changeset} ->
        {:noreply,
         assign(socket, :account_form, to_form(changeset, as: "account", action: :update))}
    end
  end
end
