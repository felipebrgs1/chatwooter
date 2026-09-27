defmodule Chatwooter.Conversations do
  @moduledoc "Bounded context de conversas e mensagens (coração do dashboard)."

  import Ecto.Query, warn: false
  alias Chatwooter.Repo

  alias Chatwooter.Accounts.Account
  alias Chatwooter.Contacts
  alias Chatwooter.Contacts.{Contact, Tag, Tagging}
  alias Chatwooter.Conversations.{Attachment, AttachmentStorage, Conversation, Message}
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

    # display_id comes from the per-account sequence via
    # conversations_before_insert_row_tr; Postgres RETURNING surfaces it.
    Repo.transaction(fn ->
      case do_open_conversation(account, inbox, contact, attrs, source_id) do
        {:ok, conversation} -> conversation
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp do_open_conversation(account, inbox, contact, attrs, source_id) do
    with {:ok, contact_inbox} <-
           Contacts.get_or_create_contact_inbox(contact, inbox, source_id) do
      %Conversation{
        account_id: account.id,
        inbox_id: inbox.id,
        contact_inbox_id: contact_inbox.id,
        contact_id: contact.id,
        uuid: Ecto.UUID.generate(),
        last_activity_at: DateTime.utc_now()
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
    |> hydrate_conversation()
  end

  @doc "Busca mensagem com anexos (thread)."
  def get_message!(id) do
    Message |> Repo.get!(id) |> Repo.preload(:attachments) |> hydrate_message()
  end

  @doc """
  Anexa um arquivo já hospedado no storage à mensagem e avisa os assinantes.
  """
  def create_attachment(%Message{} = message, attrs) do
    result = Repo.transaction(fn -> insert_attachment_with_storage(message, attrs) end)

    case result do
      {:ok, attachment} ->
        full = get_message!(message.id)
        broadcast_message(full, {:message_updated, full})
        {:ok, attachment}

      {:error, _} = error ->
        error
    end
  end

  defp insert_attachment_with_storage(message, attrs) do
    changeset =
      %Attachment{message_id: message.id, account_id: message.account_id}
      |> Attachment.changeset(attrs)

    with {:ok, attachment} <- Repo.insert(changeset),
         {:ok, _storage} <- insert_attachment_storage(attachment, message.id) do
      attachment
    else
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp insert_attachment_storage(attachment, message_id) do
    storage = %AttachmentStorage{
      attachment_id: attachment.id,
      message_id: message_id,
      key: attachment.key,
      url: attachment.url,
      content_type: attachment.content_type,
      size_bytes: attachment.size_bytes,
      metadata: attachment.metadata
    }

    storage
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.unique_constraint([:message_id, :key],
      name: :chatwooter_attachment_storage_message_key
    )
    |> Repo.insert()
  end

  @doc "Lista os anexos de uma mensagem."
  def list_attachments(%Message{id: id}) do
    Repo.all(from a in Attachment, where: a.message_id == ^id, order_by: [asc: a.id])
    |> Enum.map(&hydrate_attachment/1)
  end

  @doc "Busca anexo pela chave de storage (idempotência de download)."
  def fetch_attachment(message_id, key) do
    case Repo.one(
           from a in Attachment,
             join: st in AttachmentStorage,
             on: st.attachment_id == a.id,
             where: st.message_id == ^message_id and st.key == ^key
         ) do
      %Attachment{} = attachment -> {:ok, hydrate_attachment(attachment)}
      nil -> {:error, :not_found}
    end
  end

  @doc "Busca mensagem por id (workers de envio)."
  def fetch_message(id) do
    case Repo.get(Message, id) do
      %Message{} = message -> {:ok, Message.hydrate(message)}
      nil -> {:error, :not_found}
    end
  end

  # Como o `unread_incoming_messages.count` do Chatwoot: incoming após o
  # agent_last_seen_at, limitado a 10 (a UI mostra "9+").
  defmacrop unread_count(c) do
    quote do
      fragment(
        "LEAST((SELECT count(*) FROM messages m WHERE m.conversation_id = ? AND m.message_type = 0 AND (? IS NULL OR m.created_at > ?)), 10)",
        unquote(c).id,
        unquote(c).agent_last_seen_at,
        unquote(c).agent_last_seen_at
      )
    end
  end

  @doc """
  Lista de conversas (ConversationFinder do Chatwoot).

  Opções: `:status` (`"open"`, `"pending"`, `"resolved"`, `"snoozed"` ou `"all"`),
  `:inbox_id`, `:team_id`, `:label` (título), `:conversation_type` (`"mention"`,
  `"participating"`, `"unattended"`), `:search`, `:assignee_type` (`"me"`,
  `"unassigned"`, `"all"`) com `:user_id`, e `:sort_by` com as chaves do
  `Conversations::SortService`.
  """
  def list_conversations(%Account{id: account_id}, opts \\ []) do
    messages_query = from(m in Message, order_by: [asc: m.id])

    account_id
    |> conversations_query(opts)
    |> filter_assignee(Keyword.get(opts, :assignee_type, "all"), Keyword.get(opts, :user_id))
    |> select_merge([c], %{unread_count: unread_count(c)})
    |> sort_conversations(Keyword.get(opts, :sort_by))
    |> preload([:assignee, contact_inbox: [:contact, :inbox], messages: ^messages_query])
    |> Repo.all()
    |> Repo.preload(messages: :attachments)
    |> Enum.map(&hydrate_conversation/1)
  end

  @doc "Contadores das abas Mine / Unassigned / All para os mesmos filtros."
  def conversation_counts(%Account{id: account_id}, opts) do
    user_id = Keyword.fetch!(opts, :user_id)

    account_id
    |> conversations_query(opts)
    |> select([c], %{
      mine: filter(count(c.id), c.assignee_id == ^user_id),
      unassigned: filter(count(c.id), is_nil(c.assignee_id) and is_nil(c.assignee_agent_bot_id)),
      all: count(c.id)
    })
    |> Repo.one()
  end

  @doc "Marca a conversa como vista pelo agente (zera o unread_count)."
  def mark_seen(%Conversation{id: id}) do
    now = DateTime.utc_now()

    {1, _} =
      Repo.update_all(from(c in Conversation, where: c.id == ^id), set: [agent_last_seen_at: now])

    {:ok, now}
  end

  defp conversations_query(account_id, opts) do
    Conversation
    |> where([c], c.account_id == ^account_id)
    |> filter_status(Keyword.get(opts, :status, "all"))
    |> filter_inbox(Keyword.get(opts, :inbox_id))
    |> filter_team(Keyword.get(opts, :team_id))
    |> filter_label(Keyword.get(opts, :label))
    |> filter_conversation_type(
      Keyword.get(opts, :conversation_type),
      Keyword.get(opts, :user_id)
    )
    |> filter_search(Keyword.get(opts, :search, ""))
  end

  # mentions e conversation_participants são lidas pelo nome da tabela: os
  # schemas ficam em contexts que dependem deste.
  defp filter_conversation_type(query, "mention", user_id) when not is_nil(user_id) do
    ids = from m in "mentions", where: m.user_id == ^user_id, select: m.conversation_id
    where(query, [c], c.id in subquery(ids))
  end

  defp filter_conversation_type(query, "participating", user_id) when not is_nil(user_id) do
    ids =
      from p in "conversation_participants",
        where: p.user_id == ^user_id,
        select: p.conversation_id

    where(query, [c], c.id in subquery(ids))
  end

  defp filter_conversation_type(query, "unattended", _user_id),
    do: where(query, [c], is_nil(c.first_reply_created_at) or not is_nil(c.waiting_since))

  defp filter_conversation_type(query, type, _user_id) when type in ~w(mention participating),
    do: where(query, false)

  defp filter_conversation_type(query, _type, _user_id), do: query

  defp filter_team(query, nil), do: query
  defp filter_team(query, team_id), do: where(query, [c], c.team_id == ^team_id)

  # acts_as_taggable_on :labels (tagged_with sem strict_case_match)
  defp filter_label(query, label) when label in [nil, ""], do: query

  defp filter_label(query, label) do
    ids =
      from tg in Tagging,
        join: t in Tag,
        on: t.id == tg.tag_id,
        where:
          tg.taggable_type == "Conversation" and tg.context == "labels" and
            fragment("lower(?)", t.name) == ^String.downcase(label),
        select: tg.taggable_id

    where(query, [c], c.id in subquery(ids))
  end

  defp filter_assignee(query, "me", user_id) when not is_nil(user_id),
    do: where(query, [c], c.assignee_id == ^user_id)

  defp filter_assignee(query, "me", _user_id), do: where(query, false)

  defp filter_assignee(query, "unassigned", _user_id),
    do: where(query, [c], is_nil(c.assignee_id) and is_nil(c.assignee_agent_bot_id))

  defp filter_assignee(query, _all, _user_id), do: query

  # Conversations::SortService + SortHandler do Chatwoot
  defp sort_conversations(query, "last_activity_at_asc"),
    do: order_by(query, [c], asc: c.last_activity_at, asc: c.id)

  defp sort_conversations(query, "created_at_asc"),
    do: order_by(query, [c], asc: c.inserted_at, asc: c.id)

  defp sort_conversations(query, "created_at_desc"),
    do: order_by(query, [c], desc: c.inserted_at, desc: c.id)

  defp sort_conversations(query, "priority_desc"),
    do: order_by(query, [c], desc_nulls_last: c.priority, desc: c.last_activity_at)

  defp sort_conversations(query, "priority_asc"),
    do: order_by(query, [c], asc_nulls_last: c.priority, desc: c.last_activity_at)

  defp sort_conversations(query, "priority_desc_created_at_asc"),
    do: order_by(query, [c], desc_nulls_last: c.priority, asc: c.inserted_at)

  defp sort_conversations(query, "waiting_since_asc") do
    order_by(query, [c],
      asc: is_nil(c.waiting_since),
      asc: c.waiting_since,
      asc: c.inserted_at
    )
  end

  defp sort_conversations(query, "waiting_since_desc") do
    order_by(query, [c],
      asc: is_nil(c.waiting_since),
      desc: c.waiting_since,
      asc: c.inserted_at
    )
  end

  defp sort_conversations(query, "unread"),
    do: order_by(query, [c], desc: unread_count(c), desc: c.last_activity_at)

  defp sort_conversations(query, _default),
    do: order_by(query, [c], desc: c.last_activity_at, desc: c.id)

  defp filter_inbox(query, nil), do: query
  defp filter_inbox(query, inbox_id), do: where(query, [c], c.inbox_id == ^inbox_id)

  defp filter_status(query, status) when status in ["all", "", nil], do: query
  defp filter_status(query, status), do: where(query, [c], c.status == ^status)

  @doc "Anexos compartilhados nas conversas do contato, mais recentes primeiro (aba Media)."
  def list_contact_attachments(%Account{id: account_id}, %Contact{id: contact_id}) do
    Repo.all(
      from a in Attachment,
        join: m in Message,
        on: m.id == a.message_id,
        join: c in Conversation,
        on: c.id == m.conversation_id,
        join: ci in assoc(c, :contact_inbox),
        where: c.account_id == ^account_id and ci.contact_id == ^contact_id,
        order_by: [desc: a.id]
    )
    |> Enum.map(&hydrate_attachment/1)
  end

  @doc "Passa conversas e mensagens de um contato para outro (merge de contatos)."
  def reassign_contact(account_id, from_contact_id, to_contact_id) do
    Repo.update_all(
      from(c in Conversation,
        where: c.account_id == ^account_id and c.contact_id == ^from_contact_id
      ),
      set: [contact_id: to_contact_id]
    )

    Repo.update_all(
      from(m in Message,
        where:
          m.account_id == ^account_id and m.sender_type == "Contact" and
            m.sender_id == ^from_contact_id
      ),
      set: [sender_id: to_contact_id]
    )

    :ok
  end

  @doc "Histórico de conversas de um contato (aba History do Chatwoot)."
  def list_contact_conversations(%Account{id: account_id}, %Contact{id: contact_id}) do
    Conversation
    |> where([c], c.account_id == ^account_id)
    |> join(:inner, [c], ci in assoc(c, :contact_inbox))
    |> where([_c, ci], ci.contact_id == ^contact_id)
    |> order_by([c], desc: c.updated_at)
    |> preload(contact_inbox: [:inbox], messages: [])
    |> Repo.all()
    |> Enum.map(&hydrate_conversation/1)
  end

  @doc "Conversas de todos os contatos de uma empresa (histórico)."
  def list_company_conversations(%Account{id: account_id}, company_id) do
    Conversation
    |> where([c], c.account_id == ^account_id)
    |> join(:inner, [c], ci in assoc(c, :contact_inbox))
    |> join(:inner, [_c, ci], contact in assoc(ci, :contact))
    |> where([_c, _ci, contact], contact.company_id == ^company_id)
    |> order_by([c], desc: c.updated_at)
    |> preload(contact_inbox: [:contact, :inbox])
    |> Repo.all()
    |> Enum.map(&hydrate_conversation/1)
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
    now = DateTime.utc_now()

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

        message = Repo.preload(message, :attachments) |> hydrate_message()
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
        message = Repo.preload(message, :attachments) |> hydrate_message()
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
      Repo.transaction(fn -> receive_locked_message(conversation, normalized) end)
    end
  end

  defp receive_locked_message(conversation, normalized) do
    Repo.query!("SELECT id FROM conversations WHERE id = $1 FOR UPDATE", [conversation.id])

    case insert_or_find_message(conversation, normalized) do
      {:ok, result} -> result
      {:error, reason} -> Repo.rollback(reason)
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

  def delete_contact_data(account_id, contact_id) do
    query =
      from c in Conversation,
        left_join: ci in Chatwooter.Contacts.ContactInbox,
        on: ci.id == c.contact_inbox_id,
        where:
          c.account_id == ^account_id and
            (c.contact_id == ^contact_id or ci.contact_id == ^contact_id),
        select: c.id

    delete_conversation_data(Repo.all(query))
  end

  def delete_inbox_data(account_id, inbox_id) do
    ids =
      Repo.all(
        from c in Conversation,
          where: c.account_id == ^account_id and c.inbox_id == ^inbox_id,
          select: c.id
      )

    delete_conversation_data(ids)
  end

  defp delete_conversation_data(ids) do
    Repo.transaction(fn ->
      messages = from m in Message, where: m.conversation_id in ^ids, select: m.id
      Repo.delete_all(from s in AttachmentStorage, where: s.message_id in subquery(messages))
      Repo.delete_all(from a in Attachment, where: a.message_id in subquery(messages))
      Repo.delete_all(from m in Message, where: m.conversation_id in ^ids)
      Repo.delete_all(from c in Conversation, where: c.id in ^ids)
    end)
  end

  defp hydrate_attachment(attachment) do
    case Repo.get(AttachmentStorage, attachment.id) do
      nil ->
        %{attachment | url: attachment.external_url}

      storage ->
        fields = Map.take(storage, [:key, :url, :content_type, :size_bytes, :metadata])
        struct(attachment, fields)
    end
  end

  defp hydrate_message(message) do
    message = Message.hydrate(message)

    if Ecto.assoc_loaded?(message.attachments) do
      %{message | attachments: Enum.map(message.attachments, &hydrate_attachment/1)}
    else
      message
    end
  end

  defp hydrate_conversation(conversation) do
    conversation =
      if Ecto.assoc_loaded?(conversation.messages),
        do: %{conversation | messages: Enum.map(conversation.messages, &hydrate_message/1)},
        else: conversation

    if (Ecto.assoc_loaded?(conversation.contact_inbox) and conversation.contact_inbox) &&
         Ecto.assoc_loaded?(conversation.contact_inbox.inbox) do
      ci = conversation.contact_inbox

      %{
        conversation
        | contact_inbox: %{ci | inbox: Chatwooter.Inboxes.load_provider_config(ci.inbox)}
      }
    else
      conversation
    end
  end

  def list_canned_responses(%Account{id: account_id}) do
    Repo.all(
      from r in Chatwooter.Conversations.CannedResponse,
        where: r.account_id == ^account_id,
        order_by: r.id
    )
  end
end
