defmodule Chatwooter.Contacts do
  @moduledoc "Bounded context de contatos."

  import Ecto.Query, warn: false
  alias Chatwooter.Repo

  alias Chatwooter.Accounts.Account
  alias Chatwooter.Companies.Company
  alias Chatwooter.Contacts.{Contact, ContactInbox, CustomAttributeDefinition, Note, Tag, Tagging}
  alias Chatwooter.Inboxes
  alias Chatwooter.Inboxes.Inbox

  @doc "Lista os contatos da conta em ordem alfabética."
  def list_contacts(%Account{id: account_id}) do
    Contact
    |> where([c], c.account_id == ^account_id)
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  @doc "Busca um contato da conta (levanta se for de outra conta)."
  def get_contact!(%Account{id: account_id}, id) do
    Repo.get_by!(Contact, id: id, account_id: account_id)
  end

  @doc "Searches account contacts for the conversation filter, including name-only records."
  def search_filter_contacts(%Account{id: account_id}, query) when is_binary(query) do
    term = "%#{String.trim(query)}%"

    Contact
    |> where([c], c.account_id == ^account_id)
    |> where(
      [c],
      ilike(c.name, ^term) or ilike(c.email, ^term) or ilike(c.phone_number, ^term) or
        ilike(c.identifier, ^term)
    )
    |> order_by([c], asc: c.id)
    |> limit(15)
    |> Repo.all()
  end

  @doc "Gets a contact only when it belongs to the account."
  def get_contact(%Account{id: account_id}, id),
    do: Repo.get_by(Contact, id: id, account_id: account_id)

  @search_page_size 15

  @doc """
  Busca global de contatos (`SearchService#filter_contacts` do Chatwoot, sem
  advanced_search): ILIKE em nome, email, telefone e identifier, só contatos
  "resolvidos" (com algum identificador), 15 por página.
  """
  def search_contacts(%Account{id: account_id}, query, page \\ 1) do
    term = "%#{String.trim(query)}%"

    Contact
    |> where([c], c.account_id == ^account_id)
    |> where(
      [c],
      ilike(c.name, ^term) or ilike(c.email, ^term) or ilike(c.phone_number, ^term) or
        ilike(c.identifier, ^term)
    )
    |> where([c], c.email != "" or c.phone_number != "" or c.identifier != "")
    |> order_by([c], desc_nulls_last: c.last_activity_at, asc: c.id)
    |> limit(@search_page_size)
    |> offset(^((max(page, 1) - 1) * @search_page_size))
    |> Repo.all()
  end

  @doc "Lista as identidades do contato nos canais, incluindo o inbox."
  def list_contact_inboxes(%Account{id: account_id}, %Contact{id: contact_id}) do
    ContactInbox
    |> join(:inner, [ci], i in assoc(ci, :inbox))
    |> where([ci, i], ci.contact_id == ^contact_id and i.account_id == ^account_id)
    |> preload([ci, i], inbox: i)
    |> order_by([ci, i], asc: i.name)
    |> Repo.all()
  end

  @doc """
  Inboxes pelas quais o agente pode iniciar uma conversa com o contato
  (`Contacts::ContactableInboxesService`), como `%{inbox:, source_id:}`.
  WhatsApp vem primeiro (`CHANNEL_PRIORITY` do `composeConversationHelper.js`).
  """
  def list_contactable_inboxes(%Account{} = account, %Contact{} = contact) do
    known = Map.new(list_contact_inboxes(account, contact), &{&1.inbox_id, &1.source_id})

    account
    |> Inboxes.list_inboxes()
    |> Enum.flat_map(&contactable_inbox(&1, contact, known))
    |> Enum.sort_by(&{&1.inbox.channel_type != :whatsapp, &1.inbox.name})
  end

  # O wa_id é o telefone sem o "+" (whatsapp_contactable_inbox).
  defp contactable_inbox(%Inbox{channel_type: :whatsapp} = inbox, contact, _known) do
    case contact.phone_number do
      phone when phone in [nil, ""] -> []
      phone -> [%{inbox: inbox, source_id: String.trim_leading(phone, "+")}]
    end
  end

  # O Chatwoot não lista Telegram (o bot não pode puxar conversa com quem nunca
  # falou com ele). Aqui entra quando o contato já tem chat_id nesse inbox, que
  # é o que o Bot API exige para enviar.
  defp contactable_inbox(%Inbox{channel_type: :telegram} = inbox, _contact, known) do
    case Map.fetch(known, inbox.id) do
      {:ok, source_id} -> [%{inbox: inbox, source_id: source_id}]
      :error -> []
    end
  end

  defp contactable_inbox(_inbox, _contact, _known), do: []

  @doc "Cadastra um contato manualmente (nome + telefone/email)."
  def create_contact(%Account{} = account, attrs) do
    %Contact{account_id: account.id}
    |> Contact.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Atualiza um contato."
  def update_contact(%Contact{} = contact, attrs) do
    contact
    |> Contact.changeset(attrs)
    |> Repo.update()
  end

  @doc "Remove um contato."
  def delete_contact(%Contact{} = contact) do
    Repo.transaction(fn ->
      Repo.delete_all(from(ci in ContactInbox, where: ci.contact_id == ^contact.id))

      case Repo.delete(contact) do
        {:ok, deleted} -> deleted
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc "Changeset para formulários (sem persistir)."
  def change_contact(%Contact{} = contact, attrs \\ %{}) do
    Contact.changeset(contact, attrs)
  end

  @doc "Contatos vinculados a uma empresa."
  def list_company_contacts(%Company{id: company_id}) do
    Contact
    |> where([c], c.company_id == ^company_id)
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  @doc "Vincula um contato à empresa (sincroniza o nome da empresa)."
  def assign_company(%Contact{} = contact, %Company{id: company_id, name: name}) do
    contact
    |> Contact.changeset(%{
      company_id: company_id,
      additional_attributes: Map.put(contact.additional_attributes || %{}, "company_name", name)
    })
    |> Repo.update()
  end

  @doc "Atualiza o nome denormalizado da empresa nos contatos vinculados."
  def sync_company_name(company_id, name) do
    contacts = Repo.all(from c in Contact, where: c.company_id == ^company_id)

    Enum.each(contacts, fn contact ->
      contact
      |> Contact.changeset(%{
        additional_attributes: Map.put(contact.additional_attributes || %{}, "company_name", name)
      })
      |> Repo.update!()
    end)

    {:ok, length(contacts)}
  end

  @doc """
  Busca por telefone dentro da conta; cria se não existir (idempotente).
  """
  def get_or_create_contact(%Account{} = account, attrs) do
    phone = Map.get(attrs, :phone_number) || Map.get(attrs, "phone_number")

    case phone &&
           Repo.one(
             from(c in Contact,
               where: c.account_id == ^account.id and c.phone_number == ^phone,
               order_by: c.id,
               limit: 1
             )
           ) do
      nil ->
        %Contact{account_id: account.id}
        |> Contact.changeset(attrs)
        |> Repo.insert()

      %Contact{} = contact ->
        {:ok, contact}
    end
  end

  @doc "Busca a identidade do contato no inbox (origem do ingest de webhooks)."
  def fetch_contact_inbox(%Inbox{id: inbox_id}, source_id) do
    case Repo.get_by(ContactInbox, inbox_id: inbox_id, source_id: source_id) do
      %ContactInbox{} = contact_inbox -> {:ok, contact_inbox}
      nil -> {:error, :not_found}
    end
  end

  def get_or_create_contact_inbox(%Contact{} = contact, %Inbox{} = inbox, source_id) do
    case Repo.get_by(ContactInbox,
           contact_id: contact.id,
           inbox_id: inbox.id,
           source_id: source_id
         ) do
      nil ->
        %ContactInbox{}
        |> ContactInbox.changeset(%{
          contact_id: contact.id,
          inbox_id: inbox.id,
          source_id: source_id
        })
        |> Repo.insert()

      %ContactInbox{} = contact_inbox ->
        {:ok, contact_inbox}
    end
  end

  @doc "Reads labels from a restored database, scoped to the destination account."
  def list_labels(%Account{id: account_id}) do
    Repo.all(
      from l in Chatwooter.Contacts.Label, where: l.account_id == ^account_id, order_by: l.id
    )
  end

  @doc "Etiquetas marcadas para a sidebar, por título (`labels/getLabelsOnSidebar`)."
  def list_sidebar_labels(%Account{id: account_id}) do
    Repo.all(
      from l in Chatwooter.Contacts.Label,
        where: l.account_id == ^account_id and l.show_on_sidebar == true,
        order_by: l.title
    )
  end

  def list_custom_attribute_definitions(%Account{id: account_id}) do
    Repo.all(
      from d in Chatwooter.Contacts.CustomAttributeDefinition,
        where: d.account_id == ^account_id,
        order_by: d.id
    )
  end

  def list_notes(%Account{id: account_id}, contact_id) do
    Repo.all(
      from n in Chatwooter.Contacts.Note,
        where: n.account_id == ^account_id and n.contact_id == ^contact_id,
        order_by: [asc: n.created_at, asc: n.id]
    )
  end

  @doc "Definições de atributos customizados de contato (aba Attributes)."
  def list_contact_attribute_definitions(%Account{id: account_id}) do
    Repo.all(
      from d in CustomAttributeDefinition,
        where: d.account_id == ^account_id and d.attribute_model == :contact_attribute,
        order_by: d.id
    )
  end

  def put_custom_attribute(%Contact{} = contact, key, value) do
    update_contact(contact, %{
      custom_attributes: Map.put(contact.custom_attributes || %{}, key, value)
    })
  end

  def delete_custom_attribute(%Contact{} = contact, key) do
    update_contact(contact, %{
      custom_attributes: Map.delete(contact.custom_attributes || %{}, key)
    })
  end

  @doc "Notas do contato, mais recentes primeiro (Note.latest no Chatwoot)."
  def list_contact_notes(%Account{id: account_id}, %Contact{id: contact_id}) do
    Repo.all(
      from n in Note,
        where: n.account_id == ^account_id and n.contact_id == ^contact_id,
        order_by: [desc: n.created_at, desc: n.id],
        preload: :user
    )
  end

  def create_note(%Account{id: account_id}, %Contact{id: contact_id}, user, content) do
    %Note{account_id: account_id, contact_id: contact_id, user_id: user && user.id}
    |> Note.changeset(%{content: content})
    |> Repo.insert()
  end

  def delete_note(%Account{id: account_id}, id) do
    case Repo.get_by(Note, id: id, account_id: account_id) do
      nil -> {:error, :not_found}
      note -> Repo.delete(note)
    end
  end

  # Etiquetas de contato = acts_as_taggable_on :labels (tags + taggings)
  @label_context "labels"

  @doc "Títulos das etiquetas do contato, em ordem alfabética."
  def list_contact_labels(%Contact{id: contact_id}) do
    Repo.all(
      from t in Tag,
        join: tg in Tagging,
        on: tg.tag_id == t.id,
        where:
          tg.taggable_type == "Contact" and tg.taggable_id == ^contact_id and
            tg.context == @label_context,
        order_by: t.name,
        select: t.name
    )
  end

  def add_contact_label(%Contact{} = contact, title) do
    Repo.transaction(fn ->
      tag = Repo.get_by(Tag, name: title) || Repo.insert!(%Tag{name: title, taggings_count: 0})

      unless Repo.exists?(label_tagging(contact, tag.id)) do
        Repo.insert_all(Tagging, [
          %{
            tag_id: tag.id,
            taggable_type: "Contact",
            taggable_id: contact.id,
            context: @label_context,
            created_at: NaiveDateTime.utc_now()
          }
        ])

        Repo.update_all(from(t in Tag, where: t.id == ^tag.id), inc: [taggings_count: 1])
      end

      list_contact_labels(contact)
    end)
  end

  def remove_contact_label(%Contact{} = contact, title) do
    Repo.transaction(fn ->
      with %Tag{id: tag_id} <- Repo.get_by(Tag, name: title),
           {n, _} when n > 0 <- Repo.delete_all(label_tagging(contact, tag_id)) do
        Repo.update_all(from(t in Tag, where: t.id == ^tag_id), inc: [taggings_count: -n])
      end

      list_contact_labels(contact)
    end)
  end

  defp label_tagging(%Contact{id: contact_id}, tag_id) do
    from tg in Tagging,
      where:
        tg.tag_id == ^tag_id and tg.taggable_type == "Contact" and
          tg.taggable_id == ^contact_id and tg.context == @label_context
  end

  @mergeable_keys ~w(identifier name email phone_number additional_attributes custom_attributes)a

  @doc """
  Parte "de contatos" do ContactMergeAction: move contact_inboxes e notas do
  `mergee` para o `base`, apaga o `mergee` e mescla os atributos — os do `base`
  têm preferência, os vazios vêm do `mergee`. Conversas e mensagens ficam com
  `Chatwooter.Conversations.reassign_contact/3` (ver `Platform.ContactMerge`).
  """
  def merge_into(%Contact{} = base, %Contact{} = mergee) do
    Repo.update_all(from(ci in ContactInbox, where: ci.contact_id == ^mergee.id),
      set: [contact_id: base.id]
    )

    Repo.update_all(from(n in Note, where: n.contact_id == ^mergee.id),
      set: [contact_id: base.id]
    )

    Repo.delete_all(
      from tg in Tagging, where: tg.taggable_type == "Contact" and tg.taggable_id == ^mergee.id
    )

    merged = deep_merge(mergeable_attrs(mergee), mergeable_attrs(base))
    Repo.delete!(mergee)

    base |> Contact.changeset(merged) |> Repo.update()
  end

  defp mergeable_attrs(contact) do
    contact
    |> Map.take(@mergeable_keys)
    |> Enum.reject(fn {_key, value} -> blank?(value) end)
    |> Map.new()
  end

  defp deep_merge(left, right) do
    Map.merge(left, right, fn
      _key, %{} = l, %{} = r -> deep_merge(l, r)
      _key, _l, r -> r
    end)
  end

  defp blank?(value), do: value in [nil, "", %{}, []]

  def delete_inbox_data(%Inbox{id: inbox_id}) do
    {:ok, Repo.delete_all(from ci in ContactInbox, where: ci.inbox_id == ^inbox_id)}
  end
end
