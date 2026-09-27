defmodule Chatwooter.Inboxes do
  @moduledoc "Bounded context de inboxes (canais)."

  import Ecto.Query, warn: false
  alias Chatwooter.Repo

  alias Chatwooter.Accounts
  alias Chatwooter.Accounts.Account
  alias Chatwooter.Inboxes.{Inbox, InboxMember}

  def list_inboxes(%Account{id: account_id}) do
    Repo.all(from i in Inbox, where: i.account_id == ^account_id, order_by: [asc: i.name])
  end

  def get_inbox!(%Account{id: account_id}, id) do
    Repo.get_by!(Inbox, id: id, account_id: account_id)
  end

  def get_inbox(%Account{id: account_id}, id) do
    Repo.get_by(Inbox, id: id, account_id: account_id)
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

  def add_member(%Account{} = account, inbox_id, user_id) do
    if Repo.exists?(from i in Inbox, where: i.id == ^inbox_id and i.account_id == ^account.id) and
         Accounts.member?(account, user_id) do
      %InboxMember{}
      |> InboxMember.changeset(%{inbox_id: inbox_id, user_id: user_id})
      |> Repo.insert()
    else
      {:error, :not_found}
    end
  end

  def list_members(%Account{} = account, inbox_id) do
    get_inbox!(account, inbox_id)
    Repo.all(from m in InboxMember, where: m.inbox_id == ^inbox_id, preload: [:user])
  end

  def change_inbox(%Inbox{} = inbox, attrs \\ %{}) do
    Inbox.update_changeset(inbox, attrs)
  end

  def update_inbox(%Inbox{} = inbox, attrs) do
    attrs = normalize_attrs(attrs)

    with :ok <- validate_channel_unchanged(inbox, attrs) do
      inbox
      |> Inbox.update_changeset(merge_provider_config(inbox, attrs))
      |> Repo.update()
    end
  end

  @doc "Garante um segredo de webhook (gera e persiste se ausente)."
  def ensure_webhook_secret(%Inbox{} = inbox) do
    case (inbox.provider_config || %{})["webhook_secret"] do
      secret when is_binary(secret) and secret != "" ->
        {:ok, inbox}

      _ ->
        secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
        update_inbox(inbox, %{provider_config: %{"webhook_secret" => secret}})
    end
  end

  def delete_inbox(%Account{} = account, id) do
    account
    |> get_inbox!(id)
    |> Repo.delete()
  end

  # provider_config mescla (nunca substitui): chaves em branco removem.
  defp merge_provider_config(%Inbox{provider_config: current}, attrs) do
    case Map.get(attrs, "provider_config") do
      nil ->
        attrs

      new_config when is_map(new_config) ->
        merged =
          (current || %{})
          |> stringify_config()
          |> Map.merge(stringify_config(new_config))
          |> Enum.reject(fn {_key, value} -> blank_config_value?(value) end)
          |> Map.new()

        Map.put(attrs, "provider_config", merged)
    end
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_config(config) do
    Map.new(config, fn {key, value} -> {to_string(key), value} end)
  end

  defp blank_config_value?(nil), do: true
  defp blank_config_value?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank_config_value?(_value), do: false

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
