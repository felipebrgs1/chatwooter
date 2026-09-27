defmodule Chatwooter.Automations do
  @moduledoc "Account-scoped reads for automation data used by conversation filters."
  import Ecto.Query, warn: false
  alias Chatwooter.Accounts.Account
  alias Chatwooter.Automations.Campaign
  alias Chatwooter.Repo

  @doc "Lists campaigns available to conversation filters in one account."
  def list_campaigns(%Account{id: account_id}) do
    Repo.all(from c in Campaign, where: c.account_id == ^account_id, order_by: [asc: c.title])
  end
end
