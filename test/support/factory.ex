defmodule Chatwooter.Factory do
  @moduledoc """
  Factories ExMachina para TDD (ver `ROTEIRO_ELIXIR.md` §4).

  Os fixtures gerados pelo `phx.gen.auth` (`Chatwooter.AccountsFixtures`)
  continuam valendo para os fluxos de autenticação; as factories aqui
  cobrem o domínio Chatwooter (accounts, e em breve contacts, inboxes…).
  """

  use ExMachina.Ecto, repo: Chatwooter.Repo

  alias Chatwooter.Accounts.{Account, User}
  alias Chatwooter.Contacts.Contact
  alias Chatwooter.Conversations.{Conversation, Message}
  alias Chatwooter.Inboxes.Inbox

  def user_factory do
    email = sequence(:email, &"user#{&1}@example.com")

    %User{
      email: email,
      uid: email,
      name: "Synthetic user",
      hashed_password: Bcrypt.hash_pwd_salt("hello world!"),
      confirmed_at: DateTime.utc_now()
    }
  end

  def account_factory do
    %Account{
      name: sequence(:account_name, &"Account #{&1}")
    }
  end

  def inbox_factory do
    %Inbox{
      name: sequence(:inbox_name, &"Inbox #{&1}"),
      channel_type: :whatsapp,
      channel_id: 0
    }
  end

  def contact_factory do
    %Contact{
      name: "Maria Silva",
      phone_number: sequence(:phone_number, &"+55119#{10_000_000 + &1}")
    }
  end

  def conversation_factory do
    %Conversation{status: :open, display_id: sequence(:conversation_display_id, & &1)}
  end

  def message_factory do
    %Message{
      content: sequence(:message_content, &"Message #{&1}"),
      message_type: :incoming
    }
  end
end
