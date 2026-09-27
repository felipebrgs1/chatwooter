defmodule Chatwooter.Inboxes do
  @moduledoc "Bounded context de inboxes (canais)."

  import Ecto.Query, warn: false
  alias Chatwooter.Repo

  alias Chatwooter.Accounts
  alias Chatwooter.Accounts.Account
  alias Chatwooter.Inboxes.{Inbox, InboxConfig, InboxMember}

  def list_inboxes(%Account{id: account_id}) do
    Repo.all(from i in Inbox, where: i.account_id == ^account_id, order_by: [asc: i.name])
    |> Enum.map(&load_provider_config/1)
  end

  def get_inbox!(%Account{id: account_id}, id) do
    Repo.get_by!(Inbox, id: id, account_id: account_id) |> load_provider_config()
  end

  def get_inbox(%Account{id: account_id}, id) do
    Repo.get_by(Inbox, id: id, account_id: account_id) |> load_provider_config()
  end

  @doc "Busca inbox por id (webhooks públicos, sem escopo de conta)."
  def fetch_inbox(id) do
    case Repo.get(Inbox, id) do
      %Inbox{} = inbox -> {:ok, load_provider_config(inbox)}
      nil -> {:error, :not_found}
    end
  end

  def create_inbox(%Account{} = account, attrs) do
    changeset = Inbox.changeset(%Inbox{account_id: account.id}, attrs)

    if changeset.valid? do
      Ecto.Multi.new()
      |> Ecto.Multi.run(:channel, fn _repo, _changes -> create_channel(changeset) end)
      |> Ecto.Multi.insert(:inbox, fn %{channel: channel_id} ->
        Ecto.Changeset.put_change(changeset, :channel_id, channel_id)
      end)
      |> Ecto.Multi.insert(:config, fn %{inbox: inbox} ->
        %InboxConfig{inbox_id: inbox.id, provider_config: inbox.provider_config}
      end)
      |> Repo.transaction()
      |> inbox_result()
    else
      {:error, changeset}
    end
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
      changeset = Inbox.update_changeset(inbox, merge_provider_config(inbox, attrs))

      Ecto.Multi.new()
      |> Ecto.Multi.update(:inbox, changeset)
      |> Ecto.Multi.insert(
        :config,
        fn %{inbox: updated} ->
          %InboxConfig{inbox_id: updated.id, provider_config: updated.provider_config}
        end,
        on_conflict: {:replace, [:provider_config]},
        conflict_target: :inbox_id
      )
      |> Repo.transaction()
      |> inbox_result()
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
    inbox = get_inbox!(account, id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:config, from(c in InboxConfig, where: c.inbox_id == ^inbox.id))
    |> Ecto.Multi.delete_all(:members, from(m in InboxMember, where: m.inbox_id == ^inbox.id))
    |> Ecto.Multi.delete(:inbox, inbox)
    |> Repo.transaction()
    |> inbox_result()
  end

  @doc "Loads local adapter settings while keeping the restored inbox catalog unchanged."
  def load_provider_config(nil), do: nil

  def load_provider_config(%Inbox{} = inbox) do
    config =
      case Repo.get(InboxConfig, inbox.id) do
        nil -> restored_provider_config(inbox)
        local -> local.provider_config
      end

    %{inbox | provider_config: config || %{}}
  end

  defp restored_provider_config(%Inbox{channel_type: :telegram, channel_id: id}) do
    case Repo.get(Chatwooter.Channels.TelegramRecord, id) do
      nil -> %{}
      channel -> %{"bot_token" => channel.bot_token}
    end
  end

  defp restored_provider_config(%Inbox{channel_type: :whatsapp, channel_id: id}) do
    case Repo.get(Chatwooter.Channels.WhatsAppRecord, id) do
      nil -> %{}
      channel -> channel.provider_config || %{}
    end
  end

  defp restored_provider_config(_inbox), do: %{}

  defp inbox_result({:ok, %{inbox: inbox}}), do: {:ok, inbox}
  defp inbox_result({:error, _operation, changeset, _changes}), do: {:error, changeset}

  defp create_channel(changeset) do
    inbox = Ecto.Changeset.apply_changes(changeset)
    now = DateTime.utc_now() |> DateTime.to_naive()
    placeholder = "chatwooter-unconfigured-" <> Ecto.UUID.generate()

    case inbox.channel_type do
      :telegram ->
        token = inbox.provider_config["bot_token"] || placeholder
        row = %{account_id: inbox.account_id, bot_token: token, created_at: now, updated_at: now}
        insert_channel("channel_telegram", :bot_token, row)

      :whatsapp ->
        row = %{
          account_id: inbox.account_id,
          phone_number: placeholder,
          provider_config: inbox.provider_config,
          created_at: now,
          updated_at: now
        }

        insert_channel("channel_whatsapp", :phone_number, row)
    end
  end

  defp insert_channel(table, key, row) do
    case Repo.one(
           from c in table,
             where: field(c, ^key) == ^Map.fetch!(row, key),
             select: %{id: c.id, account_id: c.account_id}
         ) do
      nil ->
        {1, [record]} = Repo.insert_all(table, [row], returning: [:id])
        {:ok, record.id}

      %{id: id, account_id: account_id} when account_id == row.account_id ->
        {:ok, id}

      _other ->
        {:error,
         Ecto.Changeset.add_error(
           Ecto.Changeset.change(%Inbox{}),
           :provider_config,
           "channel credentials belong to another account"
         )}
    end
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

  def list_working_hours(%Account{id: account_id}, inbox_id) do
    Repo.all(
      from h in Chatwooter.Inboxes.WorkingHour,
        where: h.account_id == ^account_id and h.inbox_id == ^inbox_id,
        order_by: [asc: h.day_of_week, asc: h.id]
    )
  end
end
