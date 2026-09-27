defmodule Chatwooter.Platform.ComposeConversation do
  @moduledoc """
  Nova conversa pelo dashboard (`NewConversation/ComposeConversation.vue` →
  `ConversationsController#create`): cria conversa + mensagem e agenda a entrega.

  Fica em `Platform` porque a entrega é um worker que depende de `Conversations`.
  """

  alias Chatwooter.Accounts.Account
  alias Chatwooter.Conversations
  alias Chatwooter.Workers.TelegramSender

  @doc """
  `attrs`: `user` (vira assignee e remetente, como o `assigneeId: currentUser.id`
  do compose), `contact`, `inbox`, `source_id` e `content`.
  """
  def create(%Account{} = account, %{user: user, contact: contact, inbox: inbox} = attrs) do
    with {:ok, %{conversation: conversation, message: message}} <-
           Conversations.start_conversation(account, inbox, contact, %{
             source_id: attrs.source_id,
             assignee_id: user.id,
             content: attrs.content
           }) do
      deliver(inbox, message)
      {:ok, conversation}
    end
  end

  # Só o Telegram tem adapter de envio; o WhatsApp ainda não entrega mensagens.
  defp deliver(%{channel_type: :telegram}, message),
    do: {:ok, _job} = TelegramSender.enqueue(message)

  defp deliver(_inbox, _message), do: :ok
end
