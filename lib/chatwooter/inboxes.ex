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

  def create_inbox(%Account{} = account, attrs) do
    %Inbox{account_id: account.id}
    |> Inbox.changeset(attrs)
    |> Repo.insert()
  end

  def delete_inbox(%Account{} = account, id) do
    account
    |> get_inbox!(id)
    |> Repo.delete()
  end
end
