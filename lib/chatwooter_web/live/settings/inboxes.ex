defmodule ChatwooterWeb.SettingsLive.Inboxes do
  @moduledoc "Settings → Inboxes: criar, editar e conectar canais (WhatsApp/Telegram)."
  use ChatwooterWeb, :live_view

  alias Chatwooter.Accounts
  alias Chatwooter.Channels.Telegram.BotApi
  alias Chatwooter.Inboxes
  alias Chatwooter.Platform.RecordDeletion
  alias ChatwooterWeb.Sidebar

  @impl true
  def mount(_params, _session, socket) do
    account = socket.assigns.current_scope.user |> Accounts.list_user_accounts() |> List.first()
    {:ok, socket |> assign(:account, account) |> assign_page(account)}
  end

  defp assign_page(socket, nil), do: socket

  defp assign_page(socket, account) do
    socket
    |> assign(:inboxes, Inboxes.list_inboxes(account))
    |> assign(:inbox_form, to_form(%{"name" => "", "channel_type" => "whatsapp"}, as: "inbox"))
    |> assign(:editing_inbox_id, nil)
    |> assign(:editing_channel, nil)
    |> assign(:provider_token, nil)
    |> assign(:webhook_url, nil)
    |> assign(:editing_bot_username, nil)
    |> assign(:edit_form, nil)
  end

  @impl true
  def handle_event("create-inbox", %{"inbox" => params}, socket) do
    case Inboxes.create_inbox(socket.assigns.account, params) do
      {:ok, inbox} ->
        {:noreply,
         socket
         |> assign(:inboxes, Inboxes.list_inboxes(socket.assigns.account))
         |> Sidebar.refresh_inboxes()
         |> assign(
           :inbox_form,
           to_form(%{"name" => "", "channel_type" => "whatsapp"}, as: "inbox")
         )
         |> put_flash(:info, "Inbox #{inbox.name} created.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :inbox_form, to_form(changeset, as: "inbox", action: :insert))}
    end
  end

  def handle_event("delete-inbox", %{"id" => id}, socket) do
    {:ok, _} = RecordDeletion.delete_inbox(socket.assigns.account, id)

    {:noreply,
     socket
     |> assign(:inboxes, Inboxes.list_inboxes(socket.assigns.account))
     |> Sidebar.refresh_inboxes()
     |> put_flash(:info, "Inbox deleted.")}
  end

  def handle_event("edit-inbox", %{"id" => id}, socket) do
    inbox = Inboxes.get_inbox!(socket.assigns.account, id)

    {:noreply,
     socket
     |> assign(:editing_inbox_id, inbox.id)
     |> assign(:editing_channel, inbox.channel_type)
     |> assign(:provider_token, inbox.provider_config["bot_token"])
     |> assign(:webhook_url, telegram_webhook_url(inbox))
     |> assign(:editing_bot_username, inbox.provider_config["bot_username"])
     |> assign(:edit_form, to_form(Inboxes.change_inbox(inbox), as: "inbox"))}
  end

  def handle_event("validate-inbox", %{"inbox" => params}, socket) do
    inbox = Inboxes.get_inbox!(socket.assigns.account, socket.assigns.editing_inbox_id)

    {:noreply,
     socket
     |> assign(
       :provider_token,
       get_in(params, ["provider_config", "bot_token"]) || socket.assigns.provider_token
     )
     |> assign(
       :edit_form,
       to_form(Inboxes.change_inbox(inbox, params), as: "inbox", action: :validate)
     )}
  end

  def handle_event("save-inbox", %{"inbox" => params}, socket) do
    inbox = Inboxes.get_inbox!(socket.assigns.account, socket.assigns.editing_inbox_id)

    case Inboxes.update_inbox(inbox, params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:inboxes, Inboxes.list_inboxes(socket.assigns.account))
         |> Sidebar.refresh_inboxes()
         |> assign(:editing_inbox_id, nil)
         |> assign(:editing_channel, nil)
         |> assign(:provider_token, nil)
         |> assign(:webhook_url, nil)
         |> assign(:editing_bot_username, nil)
         |> assign(:edit_form, nil)
         |> put_flash(:info, "Inbox updated.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :edit_form, to_form(changeset, as: "inbox", action: :update))}
    end
  end

  def handle_event("cancel-edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_inbox_id, nil)
     |> assign(:editing_channel, nil)
     |> assign(:provider_token, nil)
     |> assign(:webhook_url, nil)
     |> assign(:editing_bot_username, nil)
     |> assign(:edit_form, nil)}
  end

  def handle_event("test-telegram", _params, socket) do
    inbox = Inboxes.get_inbox!(socket.assigns.account, socket.assigns.editing_inbox_id)

    case inbox.provider_config["bot_token"] do
      token when is_binary(token) and token != "" ->
        test_saved_token(socket, inbox)

      _ ->
        {:noreply, put_flash(socket, :error, "Save a bot token first.")}
    end
  end

  def handle_event("connect-telegram", _params, socket) do
    inbox = Inboxes.get_inbox!(socket.assigns.account, socket.assigns.editing_inbox_id)

    case inbox.provider_config["bot_token"] do
      token when is_binary(token) and token != "" ->
        connect_saved_inbox(socket, inbox)

      _ ->
        {:noreply, put_flash(socket, :error, "Save a bot token first.")}
    end
  end

  defp test_saved_token(socket, inbox) do
    case BotApi.get_me(inbox) do
      {:ok, %{username: username}} when is_binary(username) ->
        {:ok, _} = Inboxes.update_inbox(inbox, %{provider_config: %{"bot_username" => username}})

        {:noreply,
         socket
         |> assign(:inboxes, Inboxes.list_inboxes(socket.assigns.account))
         |> assign(:editing_bot_username, username)
         |> put_flash(:info, "Connected as @#{username}.")}

      {:ok, _} ->
        {:noreply, put_flash(socket, :error, "Telegram answered without a username.")}

      {:error, %{description: description}} when is_binary(description) ->
        {:noreply, put_flash(socket, :error, "Telegram error: #{description}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Telegram did not accept the token.")}
    end
  end

  defp connect_saved_inbox(socket, inbox) do
    with {:ok, inbox} <- Inboxes.ensure_webhook_secret(inbox),
         url = telegram_webhook_url(inbox),
         secret = inbox.provider_config["webhook_secret"],
         {:ok, _} <- BotApi.set_webhook(inbox, url, secret),
         {:ok, _} <- Inboxes.update_inbox(inbox, %{provider_config: %{"webhook_url" => url}}) do
      {:noreply,
       socket
       |> assign(:inboxes, Inboxes.list_inboxes(socket.assigns.account))
       |> put_flash(:info, "Telegram webhook connected.")}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :edit_form, to_form(changeset, as: "inbox", action: :update))}

      {:error, %{description: description}} when is_binary(description) ->
        {:noreply, put_flash(socket, :error, friendly_telegram_error(description))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not connect the webhook.")}
    end
  end

  defp friendly_telegram_error("webhook_url must be a public HTTPS URL"),
    do:
      "Telegram requires a public HTTPS URL. Expose the app (ex.: ngrok) and set WEBHOOK_BASE_URL=https://... then retry."

  defp friendly_telegram_error("Bad Request: " <> _ = description) do
    if String.contains?(description, "HTTPS URL") do
      "Telegram requires a public HTTPS URL. Expose the app (ex.: ngrok) and set WEBHOOK_BASE_URL=https://... then retry."
    else
      "Telegram error: #{description}"
    end
  end

  defp friendly_telegram_error(description), do: "Telegram error: #{description}"

  defp telegram_webhook_url(inbox) do
    base = Application.get_env(:chatwooter, :webhook_base_url) || ChatwooterWeb.Endpoint.url()
    "#{base}/webhooks/telegram/#{inbox.id}"
  end

  defp channel_badge(:whatsapp), do: {"WhatsApp", "bg-emerald-100 text-emerald-700"}
  defp channel_badge(:telegram), do: {"Telegram", "bg-sky-100 text-sky-700"}

  defp configured?(%{channel_type: :telegram, provider_config: %{"bot_token" => t}})
       when is_binary(t) and t != "",
       do: true

  defp configured?(%{
         channel_type: :whatsapp,
         provider_config: %{"phone_number_id" => p, "access_token" => t}
       })
       when is_binary(p) and p != "" and is_binary(t) and t != "",
       do: true

  defp configured?(_inbox), do: false
end
