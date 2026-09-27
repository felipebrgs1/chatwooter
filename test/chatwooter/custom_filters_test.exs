defmodule Chatwooter.CustomFiltersTest do
  use Chatwooter.DataCase

  import Chatwooter.Factory
  alias Chatwooter.Accounts
  alias Chatwooter.Accounts.{AccountUser, CustomFilter, Scope}

  setup do
    account = insert(:account)
    user = insert(:user)
    {:ok, _} = Accounts.add_member(account, user, :agent)
    %{account: account, scope: Scope.for_user(user)}
  end

  test "folders preserve the upstream query and ignore supplied ownership", ctx do
    query = %{"payload" => [%{"attribute_key" => "status", "values" => ["open"]}]}

    assert {:ok, folder} =
             Accounts.create_custom_filter(ctx.scope, ctx.account, %{
               name: "Open tickets",
               query: query,
               account_id: -1,
               user_id: -1
             })

    assert folder.account_id == ctx.account.id
    assert folder.user_id == ctx.scope.user.id
    assert folder.filter_type == 0
    assert folder.created_at
    assert [saved] = Accounts.list_custom_filters(ctx.scope, ctx.account)
    assert saved.query == query

    assert {:ok, updated} =
             Accounts.update_custom_filter(ctx.scope, ctx.account, folder.id, %{
               name: "Urgent tickets",
               query: %{"payload" => []}
             })

    assert updated.name == "Urgent tickets"
    assert updated.query == %{"payload" => []}
    assert {:ok, _} = Accounts.delete_custom_filter(ctx.scope, ctx.account, folder.id)
    assert [] == Accounts.list_custom_filters(ctx.scope, ctx.account)
  end

  test "folders are private to their owner and account", ctx do
    {:ok, folder} =
      Accounts.create_custom_filter(ctx.scope, ctx.account, %{name: "Mine", query: %{}})

    other = insert(:user)
    {:ok, _} = Accounts.add_member(ctx.account, other, :agent)
    scope = Scope.for_user(other)
    assert [] == Accounts.list_custom_filters(scope, ctx.account)
    assert nil == Accounts.get_custom_filter(scope, ctx.account, folder.id)

    assert {:error, :not_found} ==
             Accounts.update_custom_filter(scope, ctx.account, folder.id, %{name: "Stolen"})

    assert {:error, :not_found} ==
             Accounts.delete_custom_filter(scope, ctx.account, folder.id)

    foreign = insert(:account)
    assert [] == Accounts.list_custom_filters(ctx.scope, foreign)
    assert nil == Accounts.get_custom_filter(ctx.scope, foreign, folder.id)

    assert {:error, :unauthorized} ==
             Accounts.create_custom_filter(ctx.scope, foreign, %{name: "Foreign", query: %{}})
  end

  test "validates required fields and filter types without coercing restored queries", ctx do
    assert {:error, changeset} = Accounts.create_custom_filter(ctx.scope, ctx.account, %{})
    assert %{name: ["can't be blank"], query: ["can't be blank"]} = errors_on(changeset)

    assert {:error, changeset} =
             Accounts.create_custom_filter(ctx.scope, ctx.account, %{
               name: "Invalid",
               query: %{},
               filter_type: 9
             })

    assert %{filter_type: ["is invalid"]} = errors_on(changeset)

    assert {:ok, segment} =
             Accounts.create_custom_filter(ctx.scope, ctx.account, %{
               name: "Contacts",
               query: %{"payload" => []},
               filter_type: 1
             })

    assert [] == Accounts.list_custom_filters(ctx.scope, ctx.account)
    assert [^segment] = Accounts.list_custom_filters(ctx.scope, ctx.account, 1)
  end

  test "limits all saved view types together per user and account", ctx do
    now = NaiveDateTime.utc_now()

    rows =
      for index <- 1..1000 do
        %{
          name: "Saved #{index}",
          query: %{},
          filter_type: rem(index, 3),
          account_id: ctx.account.id,
          user_id: ctx.scope.user.id,
          created_at: now,
          updated_at: now
        }
      end

    Repo.insert_all(CustomFilter, rows)

    assert {:error, changeset} =
             Accounts.create_custom_filter(ctx.scope, ctx.account, %{name: "Overflow", query: %{}})

    assert %{account_id: ["maximum saved filters reached"]} = errors_on(changeset)

    other = insert(:account)
    {:ok, _} = Accounts.add_member(other, ctx.scope.user, :agent)

    assert {:ok, _} =
             Accounts.create_custom_filter(ctx.scope, other, %{name: "Allowed", query: %{}})
  end

  test "revoked membership denies access to existing folders", ctx do
    {:ok, folder} =
      Accounts.create_custom_filter(ctx.scope, ctx.account, %{name: "Mine", query: %{}})

    Repo.get_by!(AccountUser, account_id: ctx.account.id, user_id: ctx.scope.user.id)
    |> Repo.delete!()

    assert [] == Accounts.list_custom_filters(ctx.scope, ctx.account)

    assert {:error, :not_found} ==
             Accounts.delete_custom_filter(ctx.scope, ctx.account, folder.id)

    assert {:error, :unauthorized} ==
             Accounts.create_custom_filter(ctx.scope, ctx.account, %{name: "Denied", query: %{}})
  end
end
