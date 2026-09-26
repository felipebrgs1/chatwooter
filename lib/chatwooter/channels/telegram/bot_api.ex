defmodule Chatwooter.Channels.Telegram.BotApi do
  @moduledoc "Adapter da Telegram Bot API via webhook (Fase 2). HTTP via `Req`."

  @behaviour Chatwooter.Channels.Channel

  @default_base "https://api.telegram.org"
  @secret_header "x-telegram-bot-api-secret-token"

  @impl true
  def send_message(%{provider_config: %{"bot_token" => token}}, message)
      when is_binary(token) and token != "" do
    body =
      %{"chat_id" => message.to, "text" => message.content}
      |> maybe_put_reply(message)

    case Req.post("#{api_base()}/bot#{token}/sendMessage", json: body) do
      {:ok, %Req.Response{status: 200, body: %{"ok" => true, "result" => %{"message_id" => id}}}} ->
        {:ok, %{external_id: to_string(id)}}

      {:ok, %Req.Response{body: %{"ok" => false} = body}} ->
        {:error, %{code: body["error_code"], description: body["description"]}}

      {:ok, %Req.Response{status: status}} ->
        {:error, %{code: status, description: "unexpected telegram status"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def send_message(_inbox, _message), do: {:error, :missing_bot_token}

  @doc "Baixa um arquivo do Telegram (`getFile` + conteúdo)."
  def download_file(%{provider_config: %{"bot_token" => token}}, file_id)
      when is_binary(token) and token != "" and is_binary(file_id) do
    with {:ok, %{"result" => %{"file_path" => path}}} <- get_file(token, file_id),
         {:ok, %Req.Response{status: 200} = resp} <-
           Req.get("#{api_base()}/file/bot#{token}/#{path}") do
      {:ok,
       %{
         bytes: resp.body,
         content_type: response_content_type(resp, path),
         file_path: path
       }}
    else
      {:ok, %Req.Response{body: %{"ok" => false} = body}} ->
        {:error, %{code: body["error_code"], description: body["description"]}}

      {:ok, %Req.Response{status: status}} ->
        {:error, %{code: status, description: "unexpected telegram status"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def download_file(_inbox, _file_id), do: {:error, :missing_bot_token}

  defp get_file(token, file_id) do
    case Req.get("#{api_base()}/bot#{token}/getFile", params: [file_id: file_id]) do
      {:ok, %Req.Response{status: 200, body: %{"ok" => true} = body}} -> {:ok, body}
      {:ok, %Req.Response{} = resp} -> {:ok, resp}
      {:error, reason} -> {:error, reason}
    end
  end

  defp response_content_type(resp, path) do
    case Req.Response.get_header(resp, "content-type") do
      [content_type | _] -> content_type |> String.split(";") |> hd() |> String.trim()
      [] -> content_type_by_extension(path)
    end
  end

  @extension_content_types %{
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".png" => "image/png",
    ".webp" => "image/webp",
    ".gif" => "image/gif",
    ".mp4" => "video/mp4",
    ".ogg" => "audio/ogg",
    ".oga" => "audio/ogg",
    ".mp3" => "audio/mpeg",
    ".pdf" => "application/pdf"
  }

  defp content_type_by_extension(path) do
    Map.get(
      @extension_content_types,
      Path.extname(String.downcase(path || "")),
      "application/octet-stream"
    )
  end

  @impl true
  def parse_webhook(%{"message" => message}) when is_map(message), do: parse_message(message)
  def parse_webhook(_params), do: {:ok, []}

  @impl true
  def validate_webhook(conn, %{provider_config: %{"webhook_secret" => secret}})
      when is_binary(secret) and secret != "" do
    case Plug.Conn.get_req_header(conn, @secret_header) do
      [^secret] -> :ok
      _ -> {:error, :unauthorized}
    end
  end

  def validate_webhook(_conn, _inbox), do: :ok

  defp parse_message(%{"message_id" => id, "chat" => %{"id" => chat_id}} = msg) do
    base = %{
      channel: :telegram,
      source_id: to_string(chat_id),
      sender_name: get_in(msg, ["from", "first_name"]),
      external_id: to_string(id),
      timestamp: msg["date"]
    }

    cond do
      is_binary(msg["text"]) ->
        {:ok, [Map.merge(base, %{type: :text, content: msg["text"], file_id: nil})]}

      is_list(msg["photo"]) and msg["photo"] != [] ->
        file_id = msg["photo"] |> List.last() |> Map.get("file_id")
        {:ok, [Map.merge(base, %{type: :image, content: msg["caption"], file_id: file_id})]}

      true ->
        {:ok, []}
    end
  end

  defp parse_message(_message), do: {:ok, []}

  defp maybe_put_reply(body, %{reply_to_external_id: id}) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> Map.put(body, "reply_to_message_id", int)
      _ -> body
    end
  end

  defp maybe_put_reply(body, _message), do: body

  defp api_base do
    Application.get_env(:chatwooter, :telegram_api_base, @default_base)
  end
end
