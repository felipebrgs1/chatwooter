defmodule Chatwooter.AccountsAgentsTest do
  @moduledoc "Agents estilo Chatwoot: User(name, email) + AccountUser(role, availability)."
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Repo}
  alias Chatwooter.Accounts.{AccountUser, User}

  setup do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)
    %{account: account, owner: owner}
  end

  test "create_agent/2 creates user and offline membership", %{account: account} do
    assert {:ok, %User{name: "Maria", email: "maria@example.com"}} =
             Accounts.create_agent(account, %{name: "Maria", email: "maria@example.com"})

    membership =
      Repo.get_by!(AccountUser,
        account_id: account.id,
        user_id: Repo.get_by!(User, email: "maria@example.com").id
      )

    assert membership.role == :agent
    assert membership.availability == :offline
  end

  test "create_agent/2 defaults blank name to the email prefix", %{account: account} do
    assert {:ok, %User{name: "maria"}} =
             Accounts.create_agent(account, %{name: "", email: "maria@example.com"})
  end

  test "create_agent/2 accepts role and availability", %{account: account} do
    assert {:ok, %User{}} =
             Accounts.create_agent(account, %{
               name: "Boss",
               email: "boss@example.com",
               role: "administrator",
               availability: "busy"
             })

    membership =
      Repo.get_by!(AccountUser,
        account_id: account.id,
        user_id: Repo.get_by!(User, email: "boss@example.com").id
      )

    assert membership.role == :administrator
    assert membership.availability == :busy
  end

  test "create_agent/2 rejects invalid email and short name", %{account: account} do
    assert {:error, %Ecto.Changeset{} = changeset} =
             Accounts.create_agent(account, %{name: "Maria", email: "nope"})

    assert %{email: [_]} = errors_on(changeset)

    assert {:error, %Ecto.Changeset{} = changeset} =
             Accounts.create_agent(account, %{name: "X", email: "x@example.com"})

    assert %{name: [_]} = errors_on(changeset)
  end

  test "create_agent/2 reuses an existing user for a new account", %{
    account: account,
    owner: owner
  } do
    other_owner = insert(:user)
    {:ok, other_account} = Accounts.create_account(%{name: "Other"}, other_owner)

    assert {:ok, %User{id: id}} =
             Accounts.create_agent(other_account, %{name: "Ignored", email: owner.email})

    assert id == owner.id

    assert %AccountUser{} =
             Repo.get_by(AccountUser, account_id: other_account.id, user_id: owner.id)

    assert %AccountUser{} = Repo.get_by(AccountUser, account_id: account.id, user_id: owner.id)
  end

  test "create_agent/2 errors when already a member", %{account: account, owner: owner} do
    assert {:error, _} = Accounts.create_agent(account, %{name: "Owner", email: owner.email})
  end

  test "update_agent/3 updates name, role and availability", %{account: account} do
    {:ok, user} = Accounts.create_agent(account, %{name: "Maria", email: "maria@example.com"})

    assert {:ok, %User{name: "Maria Silva"}} =
             Accounts.update_agent(account, user, %{
               name: "Maria Silva",
               email: "maria@example.com",
               role: "administrator",
               availability: "busy"
             })

    membership = Repo.get_by!(AccountUser, account_id: account.id, user_id: user.id)
    assert membership.role == :administrator
    assert membership.availability == :busy
  end

  test "update_agent/3 refuses to demote the last admin", %{account: account, owner: owner} do
    assert {:error, :last_admin} =
             Accounts.update_agent(account, owner, %{
               name: "Owner",
               email: owner.email,
               role: "agent"
             })
  end

  test "update_agent/3 returns not_found outside the account", %{account: account} do
    other_owner = insert(:user)
    {:ok, _other} = Accounts.create_account(%{name: "Other"}, other_owner)

    assert {:error, :not_found} =
             Accounts.update_agent(account, other_owner, %{name: "X", email: other_owner.email})
  end
end
