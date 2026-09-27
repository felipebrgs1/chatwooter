defmodule Chatwooter.Imports.Source do
  @moduledoc "Read-only, paginated PostgreSQL source access; does not select credentials."

  @agents_sql """
  SELECT u.id, u.email, u.name, au.role, au.availability
  FROM account_users AS au
  JOIN users AS u ON u.id = au.user_id
  WHERE au.account_id = $1 AND u.id > $2
  ORDER BY u.id ASC
  LIMIT $3
  """

  @doc "Starts a separate Postgrex connection with a read-only session default, then closes it."
  def with_connection(opts, fun) when is_list(opts) and is_function(fun, 1) do
    opts =
      Keyword.update(opts, :parameters, [default_transaction_read_only: "on"], fn parameters ->
        Keyword.put(parameters, :default_transaction_read_only, "on")
      end)

    case Postgrex.start_link(opts) do
      {:ok, connection} ->
        try do
          {:ok, fun.(connection)}
        after
          GenServer.stop(connection)
        end

      {:error, _reason} ->
        {:error, :source_unavailable}
    end
  end

  @doc "Lazily reads agents in bounded pages; a second enumeration starts from ID zero."
  def stream_agents(connection, account_id, limit \\ 100)
      when is_integer(account_id) and account_id > 0 and is_integer(limit) and limit in 1..500 do
    Stream.resource(
      fn -> 0 end,
      fn cursor -> next_page(connection, account_id, cursor, limit) end,
      fn _cursor -> :ok end
    )
  end

  defp next_page(connection, account_id, cursor, limit) do
    case read_agents(connection, account_id, cursor, limit) do
      {:ok, []} -> {:halt, cursor}
      {:ok, rows} -> {rows, List.last(rows)["id"]}
      {:error, _reason} -> raise "source read failed"
    end
  end

  @doc "Runs only inside a transaction marked READ ONLY on the source connection."
  def read_only(connection, fun) when is_function(fun, 1) do
    Postgrex.transaction(connection, fn conn ->
      Postgrex.query!(conn, "SET TRANSACTION READ ONLY", [])
      fun.(conn)
    end)
  end

  @doc "Reads one bounded page of agents from one upstream account."
  def read_agents(connection, account_id, after_id, limit)
      when is_integer(account_id) and account_id > 0 and is_integer(after_id) and after_id >= 0 and
             is_integer(limit) and limit in 1..500 do
    read_only(connection, fn conn ->
      Postgrex.query!(conn, @agents_sql, [account_id, after_id, limit]).rows
      |> Enum.map(fn [id, email, name, role, availability] ->
        %{
          "id" => id,
          "email" => email,
          "name" => name,
          "role" => role,
          "availability" => availability
        }
      end)
    end)
  end

  def read_agents(_connection, _account_id, _after_id, _limit), do: {:error, :invalid_page}
end
