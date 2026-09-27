defmodule Chatwooter.ImportsTest do
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Imports, Inboxes}
  alias Chatwooter.Accounts.{AccountUser, User}
  alias Chatwooter.Imports.ImportMapping

  setup do
    owner = insert(:user)
    other_owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)
    {:ok, other} = Accounts.create_account(%{name: "Other"}, other_owner)
    %{account: account, other: other, owner: owner, other_owner: other_owner}
  end

  test "mapping is scoped by account and source table; retries never duplicate it", %{
    account: account,
    other: other,
    owner: owner,
    other_owner: other_owner
  } do
    assert {:ok, %ImportMapping{id: id}} =
             Imports.record_mapping(account, "users", 42, owner.id)

    assert {:ok, %ImportMapping{id: ^id}} =
             Imports.record_mapping(account, "users", 42, owner.id)

    assert {:ok, %ImportMapping{}} =
             Imports.record_mapping(other, "users", 42, other_owner.id)

    assert {:ok, %ImportMapping{}} = Imports.record_mapping(account, "accounts", 42, account.id)
    assert Imports.resolve(account, "users", 42) == owner.id
    assert Imports.resolve(other, "users", 42) == other_owner.id
    assert Imports.resolve(account, "users", 999) == nil
    assert Repo.aggregate(ImportMapping, :count) == 3
  end

  test "rejects cross-account, absent, unknown and conflicting targets", %{
    account: account,
    other: other,
    owner: owner,
    other_owner: outsider
  } do
    agent = insert(:user)
    {:ok, _} = Accounts.add_member(account, agent)
    {:ok, team} = Accounts.create_team(account, %{name: "Support"})
    {:ok, other_team} = Accounts.create_team(other, %{name: "Support"})
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Telegram", channel_type: "telegram"})

    {:ok, other_inbox} =
      Inboxes.create_inbox(other, %{name: "Telegram", channel_type: "telegram"})

    assert {:ok, _} = Imports.record_mapping(account, "teams", 50, team.id)
    assert {:ok, _} = Imports.record_mapping(account, "inboxes", 50, inbox.id)
    assert {:error, :not_found} = Imports.record_mapping(account, "teams", 51, other_team.id)
    assert {:error, :not_found} = Imports.record_mapping(account, "inboxes", 51, other_inbox.id)
    assert {:error, :not_found} = Imports.record_mapping(account, "users", 51, outsider.id)
    assert {:error, :not_found} = Imports.record_mapping(account, "accounts", 51, other.id)
    assert {:error, :not_found} = Imports.record_mapping(account, "users", 51, 99_999_999)
    assert {:error, :unsupported_table} = Imports.record_mapping(account, "secrets", 1, owner.id)
    assert {:error, :invalid_id} = Imports.record_mapping(account, "users", 0, owner.id)
    assert {:error, :invalid_id} = Imports.record_mapping(account, "users", 1, "1")
    assert {:ok, _} = Imports.record_mapping(account, "users", 52, owner.id)
    assert {:error, :conflict} = Imports.record_mapping(account, "users", 52, agent.id)
    assert {:error, :conflict} = Imports.record_mapping(account, "users", 53, owner.id)
    assert Imports.resolve(account, "users", 53) == nil
  end

  test "physical PostgreSQL constraints reject invalid IDs and duplicate target IDs", %{
    account: account,
    owner: owner
  } do
    assert {:ok, _} = Imports.record_mapping(account, "users", 10, owner.id)

    invalid =
      %ImportMapping{account_id: account.id}
      |> change(source_table: "users", old_id: 0, new_id: owner.id)
      |> check_constraint(:old_id, name: :import_mappings_positive_ids)

    assert {:error, changeset} = Repo.insert(invalid)
    assert %{old_id: [_]} = errors_on(changeset)

    duplicate =
      %ImportMapping{account_id: account.id}
      |> change(source_table: "users", old_id: 11, new_id: owner.id)
      |> unique_constraint(:new_id, name: :import_mappings_target_index)

    assert {:error, changeset} = Repo.insert(duplicate)
    assert %{new_id: [_]} = errors_on(changeset)
  end

  test "importing an agent twice preserves destination ID, membership and authentication", %{
    account: account
  } do
    row = %{
      "id" => 123,
      "email" => "agent@example.com",
      "name" => "Agent",
      "role" => 1,
      "availability" => 1,
      "encrypted_password" => "devise-hash-not-to-copy",
      "password" => "also-not-to-copy",
      "hashed_password" => "also-not-to-copy"
    }

    assert {:ok, %User{id: id}} = Imports.import_agent(account, row)
    assert {:ok, %User{id: ^id}} = Imports.import_agent(account, row)
    assert %User{hashed_password: nil, confirmed_at: nil} = Repo.get!(User, id)

    assert %AccountUser{role: :admin, availability: :offline} =
             Repo.get_by!(AccountUser, account_id: account.id, user_id: id)

    assert Imports.resolve(account, "users", 123) == id
    assert Repo.aggregate(ImportMapping, :count) == 1
    assert Repo.aggregate(User, :count) == 3
  end

  test "existing agents can be mapped without overwriting their roles or credentials", %{
    account: account,
    owner: owner
  } do
    assert {:ok, %User{id: id}} =
             Imports.import_agent(account, %{"id" => 19, "email" => owner.email, "role" => 0})

    assert id == owner.id

    assert %AccountUser{role: :admin} =
             Repo.get_by!(AccountUser, account_id: account.id, user_id: id)

    assert Repo.get!(User, id).hashed_password == owner.hashed_password
  end

  test "reused global user receives a source-scoped membership without inheriting the other account role",
       %{
         account: account,
         other: other,
         other_owner: other_owner
       } do
    assert {:ok, %User{id: id}} =
             Imports.import_agent(account, %{
               "id" => 18,
               "email" => other_owner.email,
               "role" => 0,
               "availability" => 2
             })

    assert id == other_owner.id

    assert %AccountUser{role: :agent, availability: :busy} =
             Repo.get_by!(AccountUser, account_id: account.id, user_id: id)

    assert %AccountUser{role: :admin} =
             Repo.get_by!(AccountUser, account_id: other.id, user_id: id)
  end

  test "invalid source and mapping collision roll back agent creation", %{account: account} do
    assert {:error, :invalid_source} =
             Imports.import_agent(account, %{
               "id" => 5,
               "email" => "invalid@example.com",
               "role" => 99
             })

    assert {:error, %Ecto.Changeset{}} =
             Imports.import_agent(account, %{"id" => 5, "email" => "not-an-email", "role" => 0})

    assert nil == Imports.resolve(account, "users", 5)
    assert nil == Accounts.get_user_by_email("not-an-email")

    first = %{"id" => 7, "email" => "first@example.com", "role" => 0}
    assert {:ok, %User{id: id}} = Imports.import_agent(account, first)

    assert {:error, :source_changed} =
             Imports.import_agent(account, %{first | "email" => "second@example.com"})

    assert nil == Accounts.get_user_by_email("second@example.com")
    assert Imports.resolve(account, "users", 7) == id
  end

  test "a removed membership invalidates replay instead of recreating the mapping", %{
    account: account
  } do
    row = %{"id" => 77, "email" => "removed@example.com"}
    assert {:ok, user} = Imports.import_agent(account, row)
    assert {:ok, _} = Accounts.remove_member(account, user)

    assert {:error, :stale_mapping} = Imports.import_agent(account, row)
    assert Imports.resolve(account, "users", 77) == user.id
    refute Accounts.member?(account, user.id)
  end

  test "same original agent ID in a second account cannot leak the first account user", %{
    account: account,
    other: other
  } do
    assert {:ok, %User{id: first}} =
             Imports.import_agent(account, %{"id" => 8, "email" => "one@example.com"})

    assert {:ok, %User{id: second}} =
             Imports.import_agent(other, %{"id" => 8, "email" => "two@example.com"})

    refute first == second
    assert Imports.resolve(account, "users", 8) == first
    assert Imports.resolve(other, "users", 8) == second
    assert {:error, :not_found} = Imports.record_mapping(other, "users", 9, first)
  end
end
