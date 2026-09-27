defmodule Chatwooter.CoreInboxRestoredDataTest do
  use Chatwooter.DataCase, async: true
  import Chatwooter.Factory
  alias Chatwooter.{Accounts, Inboxes}
  alias Chatwooter.Inboxes.Inbox

  test "restored polymorphic channels load without losing unsupported names" do
    for {type, expected} <- [
          {"Channel::Telegram", :telegram},
          {"Channel::Whatsapp", :whatsapp},
          {"Channel::Email", "Channel::Email"}
        ] do
      %{rows: [[id]]} =
        Repo.query!(
          """
          INSERT INTO inboxes(account_id, channel_id, name, channel_type, created_at, updated_at)
          VALUES(123, 456, 'Restored inbox', $1, '2026-09-24 10:30:00.123456',
            '2026-09-24 10:30:00.123456') RETURNING id
          """,
          [type]
        )

      inbox = Repo.get!(Inbox, id)
      assert inbox.channel_type == expected
      assert inbox.channel_id == 456
      assert inbox.inserted_at == ~U[2026-09-24 10:30:00.123456Z]
      assert inbox.account_id == 123
      assert inbox.lock_to_single_conversation == false
      assert inbox.csat_config == %{}
    end
  end

  test "local provider configuration survives reload outside the upstream inbox table" do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Parity account"}, owner)

    {:ok, inbox} =
      Inboxes.create_inbox(account, %{
        name: "Telegram parity",
        channel_type: :telegram,
        provider_config: %{
          "bot_token" => "parity-fixture-token",
          "webhook_secret" => "fixture-secret"
        }
      })

    assert inbox.channel_id > 0
    assert Inboxes.get_inbox!(account, inbox.id).provider_config == inbox.provider_config

    assert {:ok, updated} =
             Inboxes.update_inbox(inbox, %{provider_config: %{"bot_token" => "updated-token"}})

    assert Inboxes.get_inbox!(account, inbox.id).provider_config == updated.provider_config

    assert %{rows: [["Channel::Telegram"]]} =
             Repo.query!("SELECT channel_type FROM inboxes WHERE id=$1", [inbox.id])

    assert {:ok, _} = Inboxes.delete_inbox(account, inbox.id)

    assert %{rows: [[0]]} =
             Repo.query!("SELECT count(*) FROM chatwooter_inbox_configs WHERE inbox_id=$1", [
               inbox.id
             ])
  end

  test "restored Telegram credentials load through the native channel reference" do
    %{rows: [[channel_id]]} =
      Repo.query!("""
      INSERT INTO channel_telegram(account_id, bot_token, created_at, updated_at)
      VALUES(123, 'restored-telegram-fixture', now(), now()) RETURNING id
      """)

    %{rows: [[inbox_id]]} =
      Repo.query!(
        """
        INSERT INTO inboxes(account_id, channel_id, name, channel_type, created_at, updated_at)
        VALUES(123, $1, 'Restored native channel', 'Channel::Telegram', now(), now()) RETURNING id
        """,
        [channel_id]
      )

    assert {:ok, inbox} = Inboxes.fetch_inbox(inbox_id)
    assert inbox.provider_config == %{"bot_token" => "restored-telegram-fixture"}
  end
end
