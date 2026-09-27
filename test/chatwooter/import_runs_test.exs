defmodule Chatwooter.ImportRunsTest do
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Imports}
  alias Chatwooter.Accounts.User
  alias Chatwooter.Imports.{ImportError, ImportMapping, ImportRun}

  setup do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)
    %{account: account}
  end

  test "partial failure records only safe codes and rerun repairs without duplicating agents", %{
    account: account
  } do
    rows = [
      %{"id" => 101, "name" => "Agent", "email" => "agent@example.com", "role" => 0},
      %{"id" => 102, "email" => "bad-email", "password" => "super-secret", "role" => 0}
    ]

    assert {:ok, %ImportRun{status: :failed, attempts: 1, processed_count: 2, failed_count: 1}} =
             Imports.import_agents(account, 55, rows)

    assert %ImportError{source_table: "users", source_id: 102, code: "invalid_agent"} =
             Repo.one!(ImportError)

    assert nil == Imports.resolve(account, "users", 102)
    first_id = Imports.resolve(account, "users", 101)
    assert %User{} = Repo.get!(User, first_id)
    refute inspect(Repo.one!(ImportError)) =~ "super-secret"
    refute inspect(Repo.one!(ImportRun)) =~ "bad-email"

    repaired = List.replace_at(rows, 1, %{"id" => 102, "email" => "fixed@example.com"})

    assert {:ok, %ImportRun{status: :completed, attempts: 2, processed_count: 2, failed_count: 0}} =
             Imports.import_agents(account, 55, repaired)

    assert Imports.resolve(account, "users", 101) == first_id
    assert %User{} = Repo.get!(User, Imports.resolve(account, "users", 102))
    assert Repo.aggregate(ImportMapping, :count) == 2
    assert Repo.aggregate(ImportRun, :count) == 1
    assert Repo.aggregate(ImportError, :count) == 0

    assert {:ok, %ImportRun{status: :completed, attempts: 3, failed_count: 0}} =
             Imports.import_agents(account, 55, repaired)

    assert Repo.aggregate(ImportMapping, :count) == 2
  end

  test "interrupted stream resumes from persisted mappings on the next complete pass", %{
    account: account
  } do
    first = %{"id" => 201, "email" => "first@example.com"}
    second = %{"id" => 202, "email" => "second@example.com"}

    interrupted =
      Stream.concat([first], Stream.map([:fail], fn _ -> raise "source connection lost" end))

    assert_raise RuntimeError, "source connection lost", fn ->
      Imports.import_agents(account, 55, interrupted)
    end

    first_id = Imports.resolve(account, "users", 201)
    assert is_integer(first_id)
    assert %ImportRun{status: :running, attempts: 1} = Repo.one!(ImportRun)

    assert {:ok, %ImportRun{status: :completed, attempts: 2, processed_count: 2}} =
             Imports.import_agents(account, 55, [first, second])

    assert Imports.resolve(account, "users", 201) == first_id
    assert Repo.aggregate(ImportMapping, :count) == 2
  end

  test "source account is immutable for each destination account", %{account: account} do
    assert {:ok, %ImportRun{status: :completed}} = Imports.import_agents(account, 55, [])
    assert {:error, :source_account_mismatch} = Imports.import_agents(account, 56, [])
    assert %ImportRun{source_account_id: 55, attempts: 1} = Repo.one!(ImportRun)
  end

  test "run errors belong only to the intended destination account", %{account: account} do
    other_owner = insert(:user)
    {:ok, other} = Accounts.create_account(%{name: "Other"}, other_owner)
    row = %{"id" => 101, "email" => "invalid"}

    assert {:ok, %ImportRun{status: :failed}} = Imports.import_agents(account, 55, [row])
    assert {:ok, %ImportRun{status: :failed}} = Imports.import_agents(other, 55, [row])
    assert [%ImportError{source_id: 101}] = Imports.list_errors(account)
    assert [%ImportError{source_id: 101}] = Imports.list_errors(other)
    assert Repo.aggregate(ImportError, :count) == 2
  end
end
