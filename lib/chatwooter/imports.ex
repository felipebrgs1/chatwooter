defmodule Chatwooter.Imports do
  @moduledoc "Account-scoped, immutable ID mappings for resumable Chatwoot imports."

  alias Chatwooter.Accounts
  alias Chatwooter.Accounts.{Account, User}
  alias Chatwooter.Imports.{Batch, ImportMapping}
  alias Chatwooter.Inboxes
  alias Chatwooter.Repo

  @supported_tables ~w(accounts users teams inboxes)

  @doc "Imports a complete batch of source agent rows and keeps sanitized retry state."
  defdelegate import_agents(account, source_account_id, rows), to: Batch

  @doc "Read-only mapping counts from a full source agent stream; does not validate source rows."
  defdelegate preview_agents(account, source_account_id, rows), to: Batch

  @doc "Lists unresolved source IDs and safe error codes for one destination account."
  defdelegate list_errors(account), to: Batch

  @doc "Returns the mapped destination ID, or nil if this account has no mapping."
  def resolve(%Account{} = account, table, old_id)
      when table in @supported_tables and is_integer(old_id) and old_id > 0 do
    case find_mapping(account, table, old_id) do
      %ImportMapping{new_id: id} -> id
      nil -> nil
    end
  end

  def resolve(%Account{}, _table, _old_id), do: nil

  @doc "Records a single verified mapping. A retry may only repeat the same pair of IDs."
  def record_mapping(%Account{} = account, table, old_id, new_id) do
    with :ok <- validate_mapping_input(table, old_id, new_id),
         :ok <- validate_target(account, table, new_id),
         {:ok, _} <-
           %ImportMapping{account_id: account.id}
           |> ImportMapping.changeset(%{source_table: table, old_id: old_id, new_id: new_id})
           |> Repo.insert(on_conflict: :nothing) do
      confirm_mapping(account, table, old_id, new_id)
    end
  end

  defp confirm_mapping(account, table, old_id, new_id) do
    case find_mapping(account, table, old_id) do
      %ImportMapping{new_id: ^new_id} = mapping -> {:ok, mapping}
      _ -> {:error, :conflict}
    end
  end

  @doc "Imports a single source agent and its mapping atomically; no Devise credentials are read."
  def import_agent(%Account{} = account, %{"id" => old_id, "email" => email} = row) do
    with :ok <- validate_mapping_input("users", old_id, old_id),
         true <- is_binary(email),
         {:ok, role} <- role(Map.get(row, "role", 0)),
         {:ok, availability} <- availability(Map.get(row, "availability", 1)) do
      Repo.transact(fn ->
        import_agent_transaction(account, old_id, email, row, role, availability)
      end)
    else
      false -> {:error, :invalid_source}
      {:error, :invalid_id} -> {:error, :invalid_source}
      {:error, _} -> {:error, :invalid_source}
    end
  end

  def import_agent(%Account{}, _row), do: {:error, :invalid_source}

  defp import_agent_transaction(account, old_id, email, row, role, availability) do
    case find_mapping(account, "users", old_id) do
      %ImportMapping{new_id: id} -> replay_agent(account, id, email)
      nil -> create_and_map_agent(account, old_id, email, row, role, availability)
    end
  end

  defp replay_agent(account, id, email) do
    case Accounts.member?(account, id) && Accounts.get_user!(id) do
      %User{} = user ->
        if String.downcase(user.email) == String.downcase(email),
          do: {:ok, user},
          else: {:error, :source_changed}

      false ->
        {:error, :stale_mapping}
    end
  end

  defp create_and_map_agent(account, old_id, email, row, role, availability) do
    attrs = %{email: email, name: Map.get(row, "name"), role: role, availability: availability}

    with {:ok, user} <- ensure_agent(account, attrs),
         {:ok, _} <- record_mapping(account, "users", old_id, user.id) do
      {:ok, user}
    end
  end

  defp ensure_agent(account, %{email: email} = attrs) do
    case Accounts.get_user_by_email(email) do
      %User{} = user ->
        if Accounts.member?(account, user.id),
          do: {:ok, user},
          else: Accounts.create_agent(account, attrs)

      nil ->
        Accounts.create_agent(account, attrs)
    end
  end

  defp find_mapping(%Account{id: account_id}, table, old_id) do
    Repo.get_by(ImportMapping, account_id: account_id, source_table: table, old_id: old_id)
  end

  defp validate_mapping_input(table, old_id, new_id) do
    cond do
      table not in @supported_tables ->
        {:error, :unsupported_table}

      not (is_integer(old_id) and old_id > 0 and is_integer(new_id) and new_id > 0) ->
        {:error, :invalid_id}

      true ->
        :ok
    end
  end

  defp validate_target(%Account{id: id}, "accounts", id), do: :ok
  defp validate_target(%Account{}, "accounts", _id), do: {:error, :not_found}

  defp validate_target(account, "users", id),
    do: if(Accounts.member?(account, id), do: :ok, else: {:error, :not_found})

  defp validate_target(account, "teams", id),
    do: if(Accounts.get_team(account, id), do: :ok, else: {:error, :not_found})

  defp validate_target(account, "inboxes", id),
    do: if(Inboxes.get_inbox(account, id), do: :ok, else: {:error, :not_found})

  defp role(0), do: {:ok, "agent"}
  defp role(1), do: {:ok, "administrator"}
  defp role(_), do: {:error, :invalid_source}

  defp availability(0), do: {:ok, "online"}
  defp availability(1), do: {:ok, "offline"}
  defp availability(2), do: {:ok, "busy"}
  defp availability(_), do: {:error, :invalid_source}
end
