defmodule Chatwooter.AccountsAvailabilityTest do
  use Chatwooter.DataCase, async: true

  import Chatwooter.AccountsFixtures
  import Chatwooter.Factory

  alias Chatwooter.Accounts
  alias Chatwooter.Accounts.AccountUser

  setup do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, user)
    %{user: user, account: account}
  end

  test "get_membership/2 returns the user's membership in the account", %{
    user: user,
    account: account
  } do
    assert %AccountUser{availability: :online, auto_offline: true} =
             Accounts.get_membership(account, user)

    other_account = insert(:account)
    assert Accounts.get_membership(other_account, user) == nil
  end

  test "update_availability/3 changes availability and auto offline", %{
    user: user,
    account: account
  } do
    assert {:ok, %AccountUser{availability: :busy}} =
             Accounts.update_availability(account, user, %{"availability" => "busy"})

    assert {:ok, %AccountUser{availability: :busy, auto_offline: false}} =
             Accounts.update_availability(account, user, %{"auto_offline" => false})
  end

  test "update_availability/3 ignores role changes", %{user: user, account: account} do
    {:ok, membership} = Accounts.update_availability(account, user, %{"role" => "agent"})
    assert membership.role == :administrator
  end

  test "update_availability/3 rejects unknown statuses", %{user: user, account: account} do
    assert {:error, %Ecto.Changeset{}} =
             Accounts.update_availability(account, user, %{"availability" => "away"})
  end

  test "update_availability/3 fails for non-members", %{user: user} do
    assert {:error, :not_found} =
             Accounts.update_availability(insert(:account), user, %{"availability" => "busy"})
  end

  test "list_user_memberships/1 returns memberships with accounts, sorted by name", %{
    user: user,
    account: account
  } do
    {:ok, other} = Accounts.create_account(%{name: "Abc"}, user_fixture())
    {:ok, _} = Accounts.add_member(other, user)

    assert [
             %AccountUser{role: :agent, account: %{name: "Abc"}},
             %AccountUser{role: :administrator} = own
           ] =
             Accounts.list_user_memberships(user)

    assert own.account_id == account.id
  end
end
