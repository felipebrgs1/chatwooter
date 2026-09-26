defmodule Chatwooter.Workers.TelegramSenderTest do
  @moduledoc "Worker de envio p/ Telegram (fila `senders`)."
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes}
  alias Chatwooter.Conversations.Message
  alias Chatwooter.Workers.TelegramSender

  setup do
    bypass = Bypass.open()

    Application.put_env(:chatwooter, :telegram_api_base, "http://localhost:#{bypass.port}")
    on_exit(fn -> Application.delete_env(:chatwooter, :telegram_api_base) end)

    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)

    {:ok, inbox} =
      Inboxes.create_inbox(account, %{
        name: "TG",
        channel_type: "telegram",
        provider_config: %{"bot_token" => "test-token"}
      })

    {:ok, contact} = Contacts.get_or_create_contact(account, %{name: "Maria"})

    {:ok, conv} =
      Conversations.open_conversation(account, inbox, contact, %{source_id: "555"})

    %{bypass: bypass, account: account, owner: owner, conv: conv}
  end

  defp send_message(conv, owner, attrs \\ %{}) do
    {:ok, message} =
      Conversations.send_message(
        conv,
        Map.merge(%{content: "Oi", sender_id: owner.id}, attrs)
      )

    message
  end

  test "delivers the message and stores the external id", %{
    bypass: bypass,
    account: account,
    owner: owner,
    conv: conv
  } do
    Phoenix.PubSub.subscribe(Chatwooter.PubSub, "account:#{account.id}")
    message = send_message(conv, owner)

    Bypass.expect_once(bypass, "POST", "/bottest-token/sendMessage", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"chat_id" => "555", "text" => "Oi"} = Jason.decode!(body)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 99}}))
    end)

    assert {:ok, %{external_id: "99"}} =
             TelegramSender.perform(%Oban.Job{args: %{"message_id" => message.id}})

    assert_received {:message_updated, %Message{source_id: "99"}}
    assert %{source_id: "99", status: :sent} = Chatwooter.Repo.get!(Message, message.id)
  end

  test "enqueues a job for the message", %{bypass: bypass, owner: owner, conv: conv} do
    message = send_message(conv, owner)

    # Oban inline: insert já executa o perform.
    Bypass.expect_once(bypass, "POST", "/bottest-token/sendMessage", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 1}}))
    end)

    assert {:ok, %Oban.Job{queue: "senders"}} = TelegramSender.enqueue(message)
  end

  test "cancels already sent messages without calling the provider", %{
    owner: owner,
    conv: conv
  } do
    message = send_message(conv, owner, %{})
    {:ok, _} = Conversations.mark_message_sent(message, "99")

    # Sem Bypass.expect: qualquer HTTP derruba o teste.
    assert {:cancel, :already_sent} =
             TelegramSender.perform(%Oban.Job{args: %{"message_id" => message.id}})
  end

  test "marks failed and cancels on permanent provider errors", %{
    bypass: bypass,
    owner: owner,
    conv: conv
  } do
    message = send_message(conv, owner)

    Bypass.expect_once(bypass, "POST", "/bottest-token/sendMessage", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(
        200,
        Jason.encode!(%{
          "ok" => false,
          "error_code" => 400,
          "description" => "Bad Request: chat not found"
        })
      )
    end)

    assert {:cancel, _} =
             TelegramSender.perform(%Oban.Job{args: %{"message_id" => message.id}})

    assert %{status: :failed} = Chatwooter.Repo.get!(Message, message.id)
  end

  test "returns error (retry) on transport failures", %{bypass: bypass, owner: owner, conv: conv} do
    message = send_message(conv, owner)
    Bypass.down(bypass)

    assert {:error, _} =
             TelegramSender.perform(%Oban.Job{args: %{"message_id" => message.id}})
  end

  test "cancels unknown messages" do
    assert {:cancel, :not_found} =
             TelegramSender.perform(%Oban.Job{args: %{"message_id" => -1}})
  end
end
