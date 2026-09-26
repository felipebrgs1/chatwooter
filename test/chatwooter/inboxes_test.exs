defmodule Chatwooter.InboxesTest do
  @moduledoc "Fase 1: endurece o context de inboxes (base p/ Fase 2 — Telegram)."
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Inboxes}
  alias Chatwooter.Inboxes.Inbox

  setup do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)
    other_owner = insert(:user)
    {:ok, other_account} = Accounts.create_account(%{name: "Other"}, other_owner)
    %{account: account, other_account: other_account}
  end

  test "update_inbox/2 updates name and greeting", %{account: account} do
    {:ok, inbox} =
      Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    assert {:ok, %Inbox{name: "Suporte", greeting_message: "Olá! 👋"}} =
             Inboxes.update_inbox(inbox, %{name: "Suporte", greeting_message: "Olá! 👋"})
  end

  test "update_inbox/2 rejects short name and long greeting", %{account: account} do
    {:ok, inbox} =
      Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    assert {:error, %Ecto.Changeset{} = changeset} =
             Inboxes.update_inbox(inbox, %{name: "X"})

    assert %{name: ["should be at least 2 character(s)"]} = errors_on(changeset)

    assert {:error, %Ecto.Changeset{} = changeset} =
             Inboxes.update_inbox(inbox, %{greeting_message: String.duplicate("a", 1001)})

    assert %{greeting_message: [_]} = errors_on(changeset)
  end

  test "update_inbox/2 does not allow changing the channel", %{account: account} do
    {:ok, inbox} =
      Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    assert {:error, %Ecto.Changeset{} = changeset} =
             Inboxes.update_inbox(inbox, %{channel_type: "telegram"})

    assert %{channel_type: [_]} = errors_on(changeset)
    assert Inboxes.get_inbox!(account, inbox.id).channel_type == :whatsapp
  end

  test "update_inbox/2 validates provider_config per channel", %{account: account} do
    {:ok, tg} = Inboxes.create_inbox(account, %{name: "TG", channel_type: "telegram"})

    assert {:ok, _} =
             Inboxes.update_inbox(tg, %{provider_config: %{"bot_token" => "123:ABC"}})

    assert {:error, %Ecto.Changeset{} = changeset} =
             Inboxes.update_inbox(tg, %{
               provider_config: %{"bot_token" => "", "webhook_secret" => "s3cr3t"}
             })

    assert %{provider_config: [_]} = errors_on(changeset)

    {:ok, wa} = Inboxes.create_inbox(account, %{name: "WA", channel_type: "whatsapp"})

    assert {:error, %Ecto.Changeset{} = changeset} =
             Inboxes.update_inbox(wa, %{provider_config: %{"phone_number_id" => "123"}})

    assert %{provider_config: [_]} = errors_on(changeset)

    assert {:ok, _} =
             Inboxes.update_inbox(wa, %{
               provider_config: %{"phone_number_id" => "123", "access_token" => "tok"}
             })
  end

  test "update_inbox/2 treats blank provider config as unconfigured", %{account: account} do
    {:ok, tg} = Inboxes.create_inbox(account, %{name: "TG", channel_type: "telegram"})

    assert {:ok, %Inbox{provider_config: %{}}} =
             Inboxes.update_inbox(tg, %{provider_config: %{"bot_token" => ""}})
  end

  test "create_inbox/2 accepts inboxes without provider config", %{account: account} do
    assert {:ok, %Inbox{provider_config: %{}}} =
             Inboxes.create_inbox(account, %{name: "TG", channel_type: "telegram"})
  end

  test "change_inbox/2 returns a changeset", %{account: account} do
    {:ok, inbox} =
      Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    assert %Ecto.Changeset{} = Inboxes.change_inbox(inbox, %{name: "Novo"})
  end

  test "inboxes are scoped to the account", %{account: account, other_account: other} do
    {:ok, inbox} =
      Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    assert_raise Ecto.NoResultsError, fn -> Inboxes.get_inbox!(other, inbox.id) end

    assert_raise Ecto.NoResultsError, fn -> Inboxes.delete_inbox(other, inbox.id) end
    assert [%Inbox{}] = Inboxes.list_inboxes(account)
  end
end
