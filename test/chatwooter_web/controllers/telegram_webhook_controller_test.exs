defmodule ChatwooterWeb.TelegramWebhookControllerTest do
  @moduledoc "Webhook do Telegram: auth por segredo + enqueue p/ ingest (Fase 2)."
  use ChatwooterWeb.ConnCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Conversations, Inboxes}
  alias Chatwooter.Conversations.Message

  setup %{conn: conn} do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)

    {:ok, inbox} =
      Inboxes.create_inbox(account, %{
        name: "TG",
        channel_type: "telegram",
        provider_config: %{"bot_token" => "tok", "webhook_secret" => "s3cr3t"}
      })

    %{conn: conn, account: account, inbox: inbox}
  end

  defp payload do
    %{
      "update_id" => 1,
      "message" => %{
        "message_id" => 42,
        "from" => %{"id" => 111, "first_name" => "Maria"},
        "chat" => %{"id" => 555, "type" => "private"},
        "date" => 1_727_280_000,
        "text" => "Olá"
      }
    }
  end

  defp post_update(conn, inbox_id, headers) do
    conn =
      Enum.reduce(headers, conn, fn {key, value}, conn ->
        put_req_header(conn, key, value)
      end)

    post(conn, ~p"/webhooks/telegram/#{inbox_id}", Jason.encode!(payload()))
  end

  test "ingests a message and answers 200 (Oban inline)", %{
    conn: conn,
    account: account,
    inbox: inbox
  } do
    Phoenix.PubSub.subscribe(Chatwooter.PubSub, "account:#{account.id}")

    conn =
      post_update(conn, inbox.id, [
        {"content-type", "application/json"},
        {"x-telegram-bot-api-secret-token", "s3cr3t"}
      ])

    assert %{"ok" => true} = json_response(conn, 200)
    assert_received {:new_message, %Message{content: "Olá"}}

    assert [%Message{content: "Olá"}] =
             Conversations.list_conversations(account) |> Enum.flat_map(& &1.messages)
  end

  test "answers 401 on secret mismatch", %{conn: conn, inbox: inbox} do
    conn =
      post_update(conn, inbox.id, [
        {"content-type", "application/json"},
        {"x-telegram-bot-api-secret-token", "wrong"}
      ])

    assert %{"error" => _} = json_response(conn, 401)
    assert Chatwooter.Repo.aggregate(Message, :count) == 0
  end

  test "answers 404 for unknown inboxes", %{conn: conn} do
    conn =
      post_update(conn, -1, [
        {"content-type", "application/json"},
        {"x-telegram-bot-api-secret-token", "s3cr3t"}
      ])

    assert %{"error" => _} = json_response(conn, 404)
  end
end
