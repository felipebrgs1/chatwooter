# Seeds de desenvolvimento — espelha a conta padrão do Chatwoot:
# conta "Acme Inc" + usuário admin john@acme.inc / Password123!
#
# Rode com: mix ecto.setup  (ou: mix run priv/repo/seeds.exs)
# Idempotente: pode rodar quantas vezes quiser.

alias Chatwooter.Accounts
alias Chatwooter.Accounts.User
alias Chatwooter.Repo

email = "john@acme.inc"
password = "Password123!"

user =
  case Accounts.get_user_by_email(email) do
    nil ->
      {:ok, user} = Accounts.register_user(%{email: email})

      user
      |> User.confirm_changeset()
      |> Repo.update!()
      |> then(fn confirmed ->
        {:ok, {with_password, _}} =
          Accounts.update_user_password(confirmed, %{password: password})

        with_password
      end)

    %User{} = user ->
      user
  end

if Accounts.list_user_accounts(user) == [] do
  {:ok, _account} = Accounts.create_account(%{name: "Acme Inc"}, user)
end

IO.puts("Seed OK: #{email} (admin da conta Acme Inc)")

# --- Demo data p/ dashboard (idempotente) ---
alias Chatwooter.{Contacts, Conversations, Inboxes}

{:ok, account} =
  case Accounts.list_user_accounts(user) do
    [] -> Accounts.create_account(%{name: "Acme Inc"}, user)
    [account | _] -> {:ok, account}
  end

{:ok, inbox} =
  case Inboxes.list_inboxes(account) do
    [] -> Inboxes.create_inbox(account, %{name: "WhatsApp Comercial", channel_type: "whatsapp"})
    [inbox | _] -> {:ok, inbox}
  end

if Conversations.list_conversations(account) == [] do
  demo = [
    {"Maria Silva", "+5511987654321",
     [{"incoming", "Olá! Vocês entregam no fim de semana?"}, {"outgoing", "Olá, Maria! Sim, entregamos aos sábados até 12h."}],
     "open"},
    {"João Pedro", "+5511912345678", [{"incoming", "Meu pedido ainda não chegou 😟"}], "pending"},
    {"Ana Costa", "+5511977778888",
     [{"incoming", "Obrigada pelo suporte!"}, {"outgoing", "De nada, Ana! Conte sempre conosco."}],
     "resolved"}
  ]

  for {name, phone, messages, status} <- demo do
    {:ok, contact} = Contacts.get_or_create_contact(account, %{name: name, phone_number: phone})
    {:ok, conv} = Conversations.open_conversation(account, inbox, contact, %{source_id: phone})

    for {type, content} <- messages do
      attrs = %{content: content, message_type: type}
      attrs = if type == "outgoing", do: Map.put(attrs, :sender_id, user.id), else: attrs
      {:ok, _} = Conversations.add_message(conv, attrs)
    end

    {:ok, _} = Conversations.set_status(conv, status)
  end

  IO.puts("Seed OK: 3 conversas demo na #{inbox.name}")
end
