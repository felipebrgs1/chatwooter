defmodule Chatwooter.ImportSourceTest do
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Imports}
  alias Chatwooter.Imports.{ImportMapping, ImportRun, Source}

  setup do
    config = Application.fetch_env!(:chatwooter, Chatwooter.Repo)

    connection =
      start_supervised!(
        {Postgrex,
         hostname: Keyword.fetch!(config, :hostname),
         username: Keyword.fetch!(config, :username),
         password: Keyword.fetch!(config, :password),
         database: Keyword.fetch!(config, :database)}
      )

    Postgrex.query!(connection, "CREATE TEMP TABLE users (id bigint, email text, name text)", [])

    Postgrex.query!(
      connection,
      "CREATE TEMP TABLE account_users (account_id bigint, user_id bigint, role integer, availability integer)",
      []
    )

    Postgrex.query!(
      connection,
      "INSERT INTO users VALUES (1, 'one@example.com', 'One'), (2, 'two@example.com', 'Two'), (3, 'other@example.com', 'Other')",
      []
    )

    Postgrex.query!(
      connection,
      "INSERT INTO account_users VALUES (55, 1, 0, 1), (55, 2, 1, 2), (56, 3, 0, 0)",
      []
    )

    %{connection: connection}
  end

  test "opens a separate source connection read-only and always closes it" do
    config = Application.fetch_env!(:chatwooter, Chatwooter.Repo)
    opts = Keyword.take(config, [:hostname, :username, :password, :database])

    assert {:ok, ["on"]} =
             Source.with_connection(opts, fn connection ->
               send(self(), {:source_connection, connection, Process.monitor(connection)})
               Postgrex.query!(connection, "SHOW default_transaction_read_only", []).rows |> hd()
             end)

    assert_receive {:source_connection, pid, ref}
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

    assert_raise RuntimeError, "source interrupted", fn ->
      Source.with_connection(opts, fn connection ->
        send(self(), {:interrupted_connection, connection, Process.monitor(connection)})
        raise "source interrupted"
      end)
    end

    assert_receive {:interrupted_connection, pid, ref}
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
  end

  test "reads only permitted agent columns, account-scoped and keyset paginated", %{
    connection: connection
  } do
    assert {:ok, [%{"id" => 1, "email" => "one@example.com", "role" => 0} = first]} =
             Source.read_agents(connection, 55, 0, 1)

    assert Map.keys(first) |> Enum.sort() == ~w(availability email id name role)

    assert {:ok, [%{"id" => 2, "availability" => 2}]} =
             Source.read_agents(connection, 55, 1, 10)

    assert {:ok, []} = Source.read_agents(connection, 55, 2, 10)
    assert {:ok, [%{"id" => 3}]} = Source.read_agents(connection, 56, 0, 10)
    assert {:error, :invalid_page} = Source.read_agents(connection, 55, 0, 501)
  end

  test "paged source stream can be reimported after a bad row without duplicate agents", %{
    connection: connection
  } do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Destination"}, owner)

    Postgrex.query!(connection, "INSERT INTO users VALUES (4, 'invalid', 'Broken')", [])
    Postgrex.query!(connection, "INSERT INTO account_users VALUES (55, 4, 0, 1)", [])

    assert {:ok, %Imports.ImportRun{status: :failed, processed_count: 3, failed_count: 1}} =
             Imports.import_agents(account, 55, Source.stream_agents(connection, 55, 1))

    assert Imports.resolve(account, "users", 4) == nil
    first_id = Imports.resolve(account, "users", 1)

    Postgrex.query!(
      connection,
      "UPDATE users SET email = 'repaired@example.com' WHERE id = 4",
      []
    )

    assert {:ok, %Imports.ImportRun{status: :completed, processed_count: 3, failed_count: 0}} =
             Imports.import_agents(account, 55, Source.stream_agents(connection, 55, 1))

    assert Imports.resolve(account, "users", 1) == first_id
    assert is_integer(Imports.resolve(account, "users", 4))
    assert Imports.list_errors(account) == []
  end

  test "preview reports pending, mapped and stale agents without writing anything", %{
    connection: connection
  } do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Destination"}, owner)
    stream = fn -> Source.stream_agents(connection, 55, 1) end

    assert {:ok, %{source_count: 2, mapped_count: 0, pending_count: 2, stale_count: 0}} =
             Imports.preview_agents(account, 55, stream.())

    assert Repo.aggregate(ImportMapping, :count) == 0
    assert Repo.aggregate(ImportRun, :count) == 0

    assert {:ok, agent} =
             Imports.import_agent(account, %{"id" => 1, "email" => "one@example.com"})

    assert {:ok, %{source_count: 2, mapped_count: 1, pending_count: 1, stale_count: 0}} =
             Imports.preview_agents(account, 55, stream.())

    assert {:ok, _} = Accounts.remove_member(account, agent)

    assert {:ok, %{source_count: 2, mapped_count: 0, pending_count: 1, stale_count: 1}} =
             Imports.preview_agents(account, 55, stream.())

    assert Repo.aggregate(ImportRun, :count) == 0
  end

  test "preview rejects a different source for an already bound destination", %{
    connection: connection
  } do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Destination"}, owner)
    assert {:ok, _} = Imports.import_agents(account, 56, [])

    assert {:error, :source_account_mismatch} =
             Imports.preview_agents(account, 55, Source.stream_agents(connection, 55, 1))
  end

  test "source reads execute inside a read-only transaction", %{connection: connection} do
    assert {:ok, ["on"]} =
             Source.read_only(connection, fn conn ->
               Postgrex.query!(conn, "SELECT current_setting('transaction_read_only')", []).rows
               |> hd()
             end)

    assert {:error, :rollback} =
             Source.read_only(connection, fn conn ->
               result =
                 Postgrex.query(conn, "UPDATE public.accounts SET name = name WHERE false", [])

               send(self(), result)
             end)

    assert_receive {:error, %Postgrex.Error{postgres: %{code: :read_only_sql_transaction}}}

    assert {:ok, []} = Source.read_agents(connection, 55, 2, 10)
  end
end
