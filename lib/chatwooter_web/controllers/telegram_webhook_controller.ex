defmodule ChatwooterWeb.TelegramWebhookController do
  @moduledoc "Recebe updates do Telegram e enfileira o ingest (responde 200 rápido)."
  use ChatwooterWeb, :controller

  alias Chatwooter.{Channels, Inboxes}
  alias Chatwooter.Workers.TelegramIngest

  def create(conn, %{"inbox_id" => inbox_id}) do
    with {:ok, inbox} <- Inboxes.fetch_inbox(inbox_id),
         {:ok, adapter} <- Channels.for(inbox.channel_type),
         :ok <- adapter.validate_webhook(conn, inbox),
         {:ok, _job} <- enqueue_ingest(inbox, conn.body_params) do
      json(conn, %{ok: true})
    else
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "inbox not found"})

      {:error, :not_implemented} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "channel not implemented"})

      {:error, :unauthorized} ->
        conn |> put_status(:unauthorized) |> json(%{error: "invalid webhook secret"})

      {:error, _reason} ->
        conn |> put_status(:internal_server_error) |> json(%{error: "ingest failed"})
    end
  end

  defp enqueue_ingest(inbox, params) do
    %{"inbox_id" => inbox.id, "params" => params}
    |> TelegramIngest.new()
    |> Oban.insert()
  end
end
