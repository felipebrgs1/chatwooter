defmodule Chatwooter.Imports.Batch do
  @moduledoc "Retries a complete batch of agent rows; stores only source IDs and safe error codes."

  import Ecto.Query

  alias Chatwooter.Accounts
  alias Chatwooter.Accounts.Account
  alias Chatwooter.Imports
  alias Chatwooter.Imports.{ImportError, ImportRun}
  alias Chatwooter.Repo

  def import_agents(%Account{} = account, source_account_id, rows) do
    with {:ok, run} <- start_run(account, source_account_id) do
      {processed, unattributed_errors} =
        Enum.reduce(rows, {0, 0}, fn row, {processed, unattributed} ->
          {processed + 1, unattributed + import_row(account, run, row)}
        end)

      unresolved =
        Repo.aggregate(from(e in ImportError, where: e.import_run_id == ^run.id), :count)

      failed_count = unresolved + unattributed_errors
      status = if failed_count == 0, do: :completed, else: :failed

      run
      |> Ecto.Changeset.change(%{
        processed_count: processed,
        failed_count: failed_count,
        status: status
      })
      |> Repo.update()
    end
  end

  defp import_row(account, run, row) do
    case Imports.import_agent(account, row) do
      {:ok, _user} ->
        clear_error(run, row)
        0

      {:error, reason} ->
        if track_error(run, row, reason), do: 0, else: 1
    end
  end

  @doc "Counts source rows by mapping state without writing to the destination."
  def preview_agents(%Account{} = account, source_account_id, rows)
      when is_integer(source_account_id) and source_account_id > 0 do
    case Repo.get_by(ImportRun, account_id: account.id) do
      %ImportRun{source_account_id: bound_id} when bound_id != source_account_id ->
        {:error, :source_account_mismatch}

      _run ->
        {:ok, Enum.reduce(rows, empty_preview(), &count_preview_row(account, &1, &2))}
    end
  end

  def preview_agents(%Account{}, _source_account_id, _rows), do: {:error, :invalid_source_account}

  defp empty_preview do
    %{source_count: 0, mapped_count: 0, pending_count: 0, stale_count: 0}
  end

  defp count_preview_row(account, row, counts) do
    counts = %{counts | source_count: counts.source_count + 1}

    case Imports.resolve(account, "users", Map.get(row, "id")) do
      nil -> %{counts | pending_count: counts.pending_count + 1}
      id -> count_mapped_agent(account, id, counts)
    end
  end

  defp count_mapped_agent(account, id, counts) do
    if Accounts.member?(account, id),
      do: %{counts | mapped_count: counts.mapped_count + 1},
      else: %{counts | stale_count: counts.stale_count + 1}
  end

  def list_errors(%Account{id: account_id}) do
    case Repo.get_by(ImportRun, account_id: account_id) do
      nil ->
        []

      run ->
        Repo.all(from e in ImportError, where: e.import_run_id == ^run.id, order_by: e.source_id)
    end
  end

  defp start_run(%Account{} = account, source_account_id)
       when is_integer(source_account_id) and source_account_id > 0 do
    with {:ok, _} <-
           %ImportRun{account_id: account.id}
           |> ImportRun.changeset(%{source_account_id: source_account_id})
           |> Repo.insert(on_conflict: :nothing) do
      run = Repo.get_by!(ImportRun, account_id: account.id)

      if run.source_account_id == source_account_id do
        run
        |> Ecto.Changeset.change(%{attempts: run.attempts + 1, status: :running})
        |> Repo.update()
      else
        {:error, :source_account_mismatch}
      end
    end
  end

  defp start_run(%Account{}, _source_account_id), do: {:error, :invalid_source_account}

  defp clear_error(run, %{"id" => id}) when is_integer(id) and id > 0 do
    Repo.delete_all(
      from e in ImportError,
        where: e.import_run_id == ^run.id and e.source_table == "users" and e.source_id == ^id
    )
  end

  defp clear_error(_run, _row), do: :ok

  defp track_error(run, %{"id" => id}, reason) when is_integer(id) and id > 0 do
    code = error_code(reason)

    %ImportError{import_run_id: run.id, source_table: "users", source_id: id, code: code}
    |> Repo.insert(
      on_conflict: [set: [code: code, updated_at: DateTime.utc_now(:second)]],
      conflict_target: [:import_run_id, :source_table, :source_id]
    )

    true
  end

  defp track_error(_run, _row, _reason), do: false

  defp error_code(:invalid_source), do: "invalid_source"
  defp error_code(:source_changed), do: "source_changed"
  defp error_code(:stale_mapping), do: "stale_mapping"
  defp error_code(:conflict), do: "conflict"
  defp error_code(_reason), do: "invalid_agent"
end
