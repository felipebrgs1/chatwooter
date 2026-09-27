defmodule Chatwooter.Accounts.CustomFilters do
  @moduledoc "Private saved views scoped like Chatwoot's CustomFiltersController."

  import Ecto.Query
  alias Chatwooter.Accounts.{Account, AccountUser, CustomFilter, Scope}
  alias Chatwooter.Repo

  def list(%Scope{} = scope, %Account{} = account, type) do
    scope
    |> owned_query(account)
    |> where([f], f.filter_type == ^type)
    |> order_by([f], asc: f.id)
    |> Repo.all()
  end

  def get(%Scope{} = scope, %Account{} = account, id) do
    scope |> owned_query(account) |> Repo.get_by(id: id)
  end

  def create(%Scope{user: user} = scope, %Account{} = account, attrs) do
    # Lock the membership to serialize the per-user/account limit, including concurrent saves.
    Repo.transaction(fn ->
      membership =
        Repo.one(
          from m in AccountUser,
            where: m.account_id == ^account.id and m.user_id == ^user.id,
            lock: "FOR UPDATE"
        )

      if is_nil(membership), do: Repo.rollback(:unauthorized)

      now = NaiveDateTime.utc_now()

      changeset =
        %CustomFilter{
          account_id: account.id,
          user_id: user.id,
          created_at: now,
          updated_at: now
        }
        |> CustomFilter.changeset(attrs)

      changeset =
        if Repo.aggregate(owned_query(scope, account), :count) >= 1000 do
          Ecto.Changeset.add_error(changeset, :account_id, "maximum saved filters reached")
        else
          changeset
        end

      case Repo.insert(changeset) do
        {:ok, filter} -> filter
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def update(scope, account, id, attrs) do
    case get(scope, account, id) do
      nil ->
        {:error, :not_found}

      filter ->
        filter
        |> CustomFilter.changeset(attrs)
        |> Ecto.Changeset.put_change(:updated_at, NaiveDateTime.utc_now())
        |> Repo.update()
    end
  end

  def delete(scope, account, id) do
    case get(scope, account, id) do
      nil -> {:error, :not_found}
      filter -> Repo.delete(filter)
    end
  end

  defp owned_query(%Scope{user: user}, %Account{id: account_id}) do
    from f in CustomFilter,
      join: m in AccountUser,
      on: m.account_id == f.account_id and m.user_id == f.user_id,
      where: f.account_id == ^account_id and f.user_id == ^user.id
  end
end
