defmodule Chatwooter.Conversations do
  @moduledoc "Bounded context de conversas e mensagens (coração do dashboard)."

  import Ecto.Query, warn: false
  alias Chatwooter.Repo

  alias Chatwooter.Accounts.Account
  alias Chatwooter.Contacts
  alias Chatwooter.Contacts.Contact
  alias Chatwooter.Conversations.{Conversation, Message}
  alias Chatwooter.Inboxes.Inbox

  @doc """
  Abre (ou reutiliza via `ContactInbox`) uma conversa para o contato no inbox.
  """
  def open_conversation(%Account{} = account, %Inbox{} = inbox, %Contact{} = contact, attrs \\ %{}) do
    source_id =
      Map.get(attrs, :source_id) || Map.get(attrs, "source_id") || contact.phone_number

    with {:ok, contact_inbox} <-
           Contacts.get_or_create_contact_inbox(contact, inbox, source_id) do
      %Conversation{
        account_id: account.id,
        inbox_id: inbox.id,
        contact_inbox_id: contact_inbox.id,
        last_activity_at: DateTime.utc_now(:second)
      }
      |> Conversation.changeset(attrs)
      |> Repo.insert()
    end
  end

  def get_conversation!(%Account{id: account_id}, id) do
    Conversation
    |> Repo.get_by!(id: id, account_id: account_id)
    |> Repo.preload(messages: from(m in Message, order_by: [asc: m.id]), contact_inbox: [:contact, :inbox])
  end

  def list_conversations(%Account{id: account_id}, opts \\ []) do
    status = Keyword.get(opts, :status, "all")
    search = Keyword.get(opts, :search, "")

    Conversation
    |> where([c], c.account_id == ^account_id)
    |> filter_status(status)
    |> filter_search(search)
    |> order_by([c], desc: c.updated_at)
    |> preload(contact_inbox: [:contact, :inbox], messages: ^from(m in Message, order_by: [asc: m.id]))
    |> Repo.all()
  end

  defp filter_status(query, status) when status in ["all", "", nil], do: query
  defp filter_status(query, status), do: where(query, [c], c.status == ^status)

  defp filter_search(query, search) when search in ["", nil], do: query

  defp filter_search(query, search) do
    term = "%#{search}%"

    from c in query,
      join: ci in assoc(c, :contact_inbox),
      join: contact in assoc(ci, :contact),
      where:
        ilike(contact.name, ^term) or
          ilike(contact.phone_number, ^term)
  end

  def set_status(%Conversation{} = conversation, status) do
    conversation
    |> Conversation.changeset(%{status: status})
    |> Repo.update()
    |> case do
      {:ok, conv} ->
        broadcast(conv, {:conversation_updated, conv.id})
        {:ok, conv}

      error ->
        error
    end
  end

  @doc """
  Persiste a mensagem, atualiza a atividade e publica no PubSub
  (`conversation:<id>` para a thread, `account:<id>` para a lista).
  """
  def add_message(%Conversation{} = conversation, attrs) do
    now = DateTime.utc_now(:second)

    %Message{
      conversation_id: conversation.id,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id
    }
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        conversation
        |> Conversation.changeset(%{last_activity_at: now})
        |> Repo.update()

        broadcast(conversation, {:new_message, message})
        {:ok, message}

      error ->
        error
    end
  end

  defp broadcast(%Conversation{id: id, account_id: account_id}, event) do
    Phoenix.PubSub.broadcast(Chatwooter.PubSub, "conversation:#{id}", event)
    Phoenix.PubSub.broadcast(Chatwooter.PubSub, "account:#{account_id}", event)
  end
end
