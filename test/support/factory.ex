defmodule Chatwooter.Factory do
  @moduledoc """
  Factories ExMachina para TDD (ver `ROTEIRO_ELIXIR.md` §4).

  Os fixtures gerados pelo `phx.gen.auth` (`Chatwooter.AccountsFixtures`)
  continuam valendo para os fluxos de autenticação; as factories aqui
  cobrem o domínio Chatwooter (accounts, e em breve contacts, inboxes…).
  """

  use ExMachina.Ecto, repo: Chatwooter.Repo

  alias Chatwooter.Accounts.{Account, User}

  def user_factory do
    %User{
      email: sequence(:email, &"user#{&1}@example.com"),
      hashed_password: Bcrypt.hash_pwd_salt("hello world!"),
      confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  def account_factory do
    %Account{
      name: sequence(:account_name, &"Account #{&1}")
    }
  end
end
