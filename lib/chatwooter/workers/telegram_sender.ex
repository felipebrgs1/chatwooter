defmodule Chatwooter.Workers.TelegramSender do
  @moduledoc "Envio de respostas do agente p/ Telegram (fila `senders`)."
  use Oban.Worker, queue: :senders, max_attempts: 5, unique: [period: 300]

  alias Chatwooter.{Accounts, Channels, Conversations}
  alias Chatwooter.Conversations.Message

  # Erros definitivos do Telegram: retry não adianta (token, chat, bot bloqueado).
  @permanent_codes [400, 401, 403, 404]

  @doc "Enfileira o envio de uma mensagem de saída."
  def enqueue(%Message{} = message) do
    %{"message_id" => message.id}
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"message_id" => id}}) do
    with {:ok, message} <- Conversations.fetch_message(id),
         :ok <- ensure_unsent(message),
         {:ok, account} <- fetch_account(message),
         {:ok, conversation} <- fetch_conversation(account, message),
         {:ok, adapter} <- Channels.for(channel_type(conversation)) do
      deliver(adapter, conversation, message)
    else
      {:error, reason}
      when reason in [
             :not_found,
             :already_sent,
             :account_not_found,
             :conversation_not_found,
             :not_implemented
           ] ->
        {:cancel, reason}
    end
  end

  defp ensure_unsent(%Message{source_id: source_id}) when is_binary(source_id) do
    {:error, :already_sent}
  end

  defp ensure_unsent(%Message{}), do: :ok

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

  defp deliver(adapter, conversation, message) do
    inbox = conversation.contact_inbox.inbox

    payload = %{
      to: conversation.contact_inbox.source_id,
      content: message.content
    }

    case adapter.send_message(inbox, payload) do
      {:ok, %{external_id: external_id}} ->
        {:ok, _} = Conversations.mark_message_sent(message, external_id)
        {:ok, %{external_id: external_id}}

      {:error, %{code: code}} when code in @permanent_codes ->
        {:ok, _} = Conversations.mark_message_failed(message)
        {:cancel, {:permanent_error, code}}

      {:error, _} = error ->
        error
    end
  end
end
