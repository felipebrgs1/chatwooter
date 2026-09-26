defmodule Chatwooter.Workers.TelegramIngest do
  @moduledoc "Ingest de webhooks do Telegram (fila `webhook_ingest`)."
  use Oban.Worker, queue: :webhook_ingest, max_attempts: 5, unique: [period: 300]

  require Logger

  alias Chatwooter.{Accounts, Channels, Conversations, Inboxes}
  alias Chatwooter.Workers.TelegramMedia

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    with {:ok, inbox} <- Inboxes.fetch_inbox(args["inbox_id"]),
         {:ok, account} <- fetch_account(inbox),
         {:ok, adapter} <- Channels.for(inbox.channel_type) do
      {:ok, messages} = adapter.parse_webhook(args["params"])
      ingest_all(account, inbox, messages)
    else
      {:error, :not_found} -> {:cancel, :inbox_not_found}
      {:error, :account_not_found} -> {:cancel, :account_not_found}
      {:error, :not_implemented} -> {:cancel, :channel_not_implemented}
    end
  end

  defp fetch_account(%{account_id: account_id}) do
    {:ok, Accounts.get_account!(account_id)}
  rescue
    Ecto.NoResultsError -> {:error, :account_not_found}
  end

  defp ingest_all(account, inbox, messages) do
    Enum.reduce_while(messages, {:ok, %{received: 0}}, fn normalized, {:ok, acc} ->
      case Conversations.receive_message(account, inbox, normalized) do
        {:ok, %{message: message, duplicate?: false}} ->
          enqueue_media(message, normalized)
          {:cont, {:ok, %{received: acc.received + 1}}}

        {:ok, _duplicate} ->
          {:cont, {:ok, %{received: acc.received + 1}}}

        {:error, _} = error ->
          {:halt, error}
      end
    end)
  end

  defp enqueue_media(message, %{file_id: file_id}) when is_binary(file_id) do
    case TelegramMedia.enqueue(message, file_id) do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.warning("media enqueue failed for message #{message.id}: #{inspect(reason)}")
    end
  end

  defp enqueue_media(_message, _normalized), do: :ok
end
