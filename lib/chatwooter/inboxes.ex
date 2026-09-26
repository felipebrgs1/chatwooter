defmodule Chatwooter.Inboxes do
  @moduledoc "Bounded context de inboxes (canais)."

  import Ecto.Query, warn: false
  alias Chatwooter.Repo

  alias Chatwooter.Accounts.Account
  alias Chatwooter.Inboxes.Inbox

  def list_inboxes(%Account{id: account_id}) do
    Repo.all(from i in Inbox, where: i.account_id == ^account_id, order_by: [asc: i.name])
  end

  def get_inbox!(%Account{id: account_id}, id) do
    Repo.get_by!(Inbox, id: id, account_id: account_id)
  end

  @doc "Busca inbox por id (webhooks públicos, sem escopo de conta)."
  def fetch_inbox(id) do
    case Repo.get(Inbox, id) do
      %Inbox{} = inbox -> {:ok, inbox}
      nil -> {:error, :not_found}
    end
  end

  def create_inbox(%Account{} = account, attrs) do
    %Inbox{account_id: account.id}
    |> Inbox.changeset(attrs)
    |> Repo.insert()
  end

  def change_inbox(%Inbox{} = inbox, attrs \\ %{}) do
    Inbox.update_changeset(inbox, attrs)
  end

  def update_inbox(%Inbox{} = inbox, attrs) do
    with :ok <- validate_channel_unchanged(inbox, attrs) do
      inbox
      |> Inbox.update_changeset(attrs)
      |> Repo.update()
    end
  end

  def delete_inbox(%Account{} = account, id) do
    account
    |> get_inbox!(id)
    |> Repo.delete()
  end

  defp validate_channel_unchanged(%Inbox{channel_type: current}, attrs) do
    case channel_from_attrs(attrs) do
      nil -> :ok
      ^current -> :ok
      _other -> {:error, channel_immutable_changeset(current)}
    end
  end

  defp channel_from_attrs(attrs) when is_map(attrs) do
    case Map.get(attrs, :channel_type, Map.get(attrs, "channel_type")) do
      nil -> nil
      channel when is_atom(channel) -> channel
      channel when is_binary(channel) -> String.to_existing_atom(channel)
    end
  rescue
    ArgumentError -> :invalid
  end

  defp channel_immutable_changeset(current) do
    %Inbox{channel_type: current}
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.add_error(:channel_type, "cannot be changed after creation")
  end
end
