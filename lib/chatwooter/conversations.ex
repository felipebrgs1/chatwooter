defmodule Chatwooter.Conversations do
  @moduledoc "Bounded context de conversas e mensagens (coração do dashboard)."

  import Ecto.Query, warn: false
  alias Chatwooter.Repo

  alias Chatwooter.Accounts.Account
  alias Chatwooter.Contacts
  alias Chatwooter.Contacts.Contact
  alias Chatwooter.Conversations.{Attachment, Conversation, Message}
  alias Chatwooter.Inboxes.Inbox

  @doc """
  Abre (ou reutiliza via `ContactInbox`) uma conversa para o contato no inbox.
  """
  def open_conversation(
        %Account{} = account,
        %Inbox{} = inbox,
        %Contact{} = contact,
        attrs \\ %{}
      ) do
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
    |> Repo.preload(
      messages: {from(m in Message, order_by: [asc: m.id]), :attachments},
      contact_inbox: [:contact, :inbox]
    )
  end

  @doc "Busca mensagem com anexos (thread)."
  def get_message!(id) do
    Message |> Repo.get!(id) |> Repo.preload(:attachments)
  end

  @doc """
  Anexa um arquivo já hospedado no storage à mensagem e avisa os assinantes.
  """
  def create_attachment(%Message{} = message, attrs) do
    case %Attachment{message_id: message.id} |> Attachment.changeset(attrs) |> Repo.insert() do
      {:ok, attachment} ->
        full = get_message!(message.id)
        broadcast_message(full, {:message_updated, full})
        {:ok, attachment}

      {:error, _} = error ->
        error
    end
  end

  @doc "Lista os anexos de uma mensagem."
  def list_attachments(%Message{id: id}) do
    Repo.all(from a in Attachment, where: a.message_id == ^id, order_by: [asc: a.id])
  end

  @doc "Busca anexo pela chave de storage (idempotência de download)."
  def fetch_attachment(message_id, key) do
    case Repo.get_by(Attachment, message_id: message_id, key: key) do
      %Attachment{} = attachment -> {:ok, attachment}
      nil -> {:error, :not_found}
    end
  end

  @doc "Busca mensagem por id (workers de envio)."
  def fetch_message(id) do
    case Repo.get(Message, id) do
      %Message{} = message -> {:ok, message}
      nil -> {:error, :not_found}
    end
  end

  def list_conversations(%Account{id: account_id}, opts \\ []) do
    status = Keyword.get(opts, :status, "all")
    search = Keyword.get(opts, :search, "")
    messages_query = from(m in Message, order_by: [asc: m.id])

    Conversation
    |> where([c], c.account_id == ^account_id)
    |> filter_status(status)
    |> filter_search(search)
    |> order_by([c], desc: c.updated_at)
    |> preload(
      contact_inbox: [:contact, :inbox],
      messages: ^messages_query
    )
    |> Repo.all()
    |> Repo.preload(messages: :attachments)
  end

  defp filter_status(query, status) when status in ["all", "", nil], do: query
  defp filter_status(query, status), do: where(query, [c], c.status == ^status)

  @doc "Histórico de conversas de um contato (aba History do Chatwoot)."
  def list_contact_conversations(%Account{id: account_id}, %Contact{id: contact_id}) do
    Conversation
    |> where([c], c.account_id == ^account_id)
    |> join(:inner, [c], ci in assoc(c, :contact_inbox))
    |> where([_c, ci], ci.contact_id == ^contact_id)
    |> order_by([c], desc: c.updated_at)
    |> preload(contact_inbox: [:inbox], messages: [])
    |> Repo.all()
  end

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

        message = Repo.preload(message, :attachments)
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

  defp broadcast_message(%Message{conversation_id: id, account_id: account_id}, event) do
    Phoenix.PubSub.broadcast(Chatwooter.PubSub, "conversation:#{id}", event)
    Phoenix.PubSub.broadcast(Chatwooter.PubSub, "account:#{account_id}", event)
  end

  @doc """
  Persiste uma resposta do agente (entrega ao provider via worker `senders`).
  """
  def send_message(%Conversation{} = conversation, attrs) do
    attrs =
      attrs
      |> Map.new(fn {key, value} -> {to_string(key), value} end)
      |> Map.merge(%{"message_type" => "outgoing", "status" => "sent"})

    add_message(conversation, attrs)
  end

  @doc "Marca a mensagem como entregue no provider (com `external_id`)."
  def mark_message_sent(%Message{} = message, external_id) do
    update_message_delivery(message, %{source_id: external_id, status: "sent"})
  end

  @doc "Marca a mensagem como falha definitiva de entrega."
  def mark_message_failed(%Message{} = message) do
    update_message_delivery(message, %{status: "failed"})
  end

  defp update_message_delivery(%Message{} = message, attrs) do
    case message |> Message.changeset(attrs) |> Repo.update() do
      {:ok, message} ->
        message = Repo.preload(message, :attachments)
        broadcast_message(message, {:message_updated, message})
        {:ok, message}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Persiste uma mensagem normalizada vinda de um canal (ingest de webhook).

  Idempotente por `(conversation, source_id)`: retries do provider retornam
  a mensagem já criada sem duplicar. Reutiliza a conversa aberta/pendente
  do contato ou reabre a última resolvida.
  """
  def receive_message(%Account{} = account, %Inbox{} = inbox, normalized) do
    with {:ok, contact_inbox} <- ingest_contact_inbox(account, inbox, normalized),
         {:ok, conversation} <- reuse_or_open_conversation(account, inbox, contact_inbox) do
      insert_or_find_message(conversation, normalized)
    end
  end

  defp ingest_contact_inbox(account, inbox, normalized) do
    case Contacts.fetch_contact_inbox(inbox, normalized.source_id) do
      {:ok, contact_inbox} ->
        {:ok, contact_inbox}

      {:error, :not_found} ->
        with {:ok, contact} <-
               Contacts.get_or_create_contact(account, %{name: contact_name(normalized)}) do
          Contacts.get_or_create_contact_inbox(contact, inbox, normalized.source_id)
        end
    end
  end

  defp contact_name(%{sender_name: name, source_id: source_id}) do
    if is_binary(name) and String.length(String.trim(name)) >= 2 do
      String.trim(name)
    else
      "Contact #{source_id}"
    end
  end

  defp reuse_or_open_conversation(account, inbox, contact_inbox) do
    query =
      from c in Conversation,
        where: c.contact_inbox_id == ^contact_inbox.id,
        order_by: [desc: c.id],
        limit: 1

    case Repo.one(query) do
      %Conversation{status: status} = conversation when status in [:open, :pending] ->
        {:ok, conversation}

      %Conversation{} = conversation ->
        set_status(conversation, "open")

      nil ->
        contact = Repo.get!(Contact, contact_inbox.contact_id)
        open_conversation(account, inbox, contact, %{source_id: contact_inbox.source_id})
    end
  end

  defp insert_or_find_message(conversation, %{external_id: nil} = normalized) do
    insert_ingest_message(conversation, normalized)
  end

  defp insert_or_find_message(conversation, normalized) do
    case Repo.get_by(Message,
           conversation_id: conversation.id,
           source_id: normalized.external_id
         ) do
      %Message{} = message ->
        {:ok, %{conversation: conversation, message: message, duplicate?: true}}

      nil ->
        insert_ingest_message(conversation, normalized)
    end
  end

  defp insert_ingest_message(conversation, normalized) do
    attrs = %{
      content: normalized.content || "",
      content_type: to_string(normalized.type || :text),
      message_type: "incoming",
      source_id: normalized.external_id
    }

    case add_message(conversation, attrs) do
      {:ok, message} ->
        {:ok, %{conversation: conversation, message: message, duplicate?: false}}

      {:error, _} = error ->
        error
    end
  end
end
