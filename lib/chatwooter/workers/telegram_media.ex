defmodule Chatwooter.Workers.TelegramMedia do
  @moduledoc "Baixa mídia do Telegram e hospeda no object storage (fila `webhook_ingest`)."
  use Oban.Worker, queue: :webhook_ingest, max_attempts: 5, unique: [period: 300]

  alias Chatwooter.{Accounts, Channels, Conversations, Storage}

  # getFile definitivo: file_id inválido nunca vai funcionar.
  @permanent_codes [400, 401, 403, 404]

  @doc "Enfileira o download da mídia de uma mensagem recebida."
  def enqueue(message, file_id) do
    %{"message_id" => message.id, "file_id" => file_id}
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"message_id" => id, "file_id" => file_id}}) do
    with {:ok, message} <- Conversations.fetch_message(id),
         {:ok, account} <- fetch_account(message),
         {:ok, conversation} <- fetch_conversation(account, message),
         {:ok, adapter} <- Channels.for(channel_type(conversation)),
         :ok <- ensure_not_stored(message),
         {:ok, %{bytes: bytes, content_type: content_type, file_path: path}} <-
           adapter.download_file(inbox(conversation), file_id),
         {:ok, %{key: key, url: url, size_bytes: size}} <-
           Storage.put_object(storage_key(account, message, Path.basename(path)), bytes,
             content_type: content_type
           ) do
      Conversations.create_attachment(message, %{
        file_type: to_string(message.content_type || :image),
        key: key,
        url: url,
        content_type: content_type,
        size_bytes: size
      })
    else
      {:error, reason}
      when reason in [
             :not_found,
             :already_stored,
             :account_not_found,
             :conversation_not_found,
             :not_implemented
           ] ->
        {:cancel, reason}

      {:error, %{code: code}} when code in @permanent_codes ->
        {:cancel, {:permanent_error, code}}

      {:error, _} = error ->
        error
    end
  end

  defp fetch_account(%{account_id: account_id}) do
    {:ok, Accounts.get_account!(account_id)}
  rescue
    Ecto.NoResultsError -> {:error, :account_not_found}
  end

  defp fetch_conversation(account, %{conversation_id: conversation_id}) do
    {:ok, Conversations.get_conversation!(account, conversation_id)}
  rescue
    Ecto.NoResultsError -> {:error, :conversation_not_found}
  end

  defp channel_type(%{contact_inbox: %{inbox: %{channel_type: channel}}}), do: channel
  defp inbox(%{contact_inbox: %{inbox: inbox}}), do: inbox

  defp ensure_not_stored(message) do
    if Conversations.list_attachments(message) == [] do
      :ok
    else
      {:error, :already_stored}
    end
  end

  defp storage_key(account, message, filename) do
    "telegram/#{account.id}/#{message.id}/#{filename}"
  end
end
