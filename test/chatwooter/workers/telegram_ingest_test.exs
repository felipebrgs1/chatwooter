defmodule Chatwooter.Workers.TelegramIngestTest do
  @moduledoc "Worker de ingest do Telegram (fila `webhook_ingest`)."
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Conversations, Inboxes}
  alias Chatwooter.Conversations.Message
  alias Chatwooter.Workers.TelegramIngest

  setup do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)

    {:ok, inbox} =
      Inboxes.create_inbox(account, %{
        name: "TG",
        channel_type: "telegram",
        provider_config: %{"bot_token" => "tok", "webhook_secret" => "s3cr3t"}
      })

    %{account: account, inbox: inbox}
  end

  defp args(inbox_id, params) do
    %{"inbox_id" => inbox_id, "params" => params}
  end

  defp text_params(external_id \\ "42") do
    %{
      "update_id" => 1,
      "message" => %{
        "message_id" => String.to_integer(external_id),
        "from" => %{"id" => 111, "first_name" => "Maria"},
        "chat" => %{"id" => 555, "type" => "private"},
        "date" => 1_727_280_000,
        "text" => "Olá"
      }
    }
  end

  test "ingests a text message", %{account: account, inbox: inbox} do
    assert {:ok, %{received: 1}} =
             TelegramIngest.perform(%Oban.Job{args: args(inbox.id, text_params())})

    assert [%Message{content: "Olá", source_id: "42"}] =
             Conversations.list_conversations(account) |> Enum.flat_map(& &1.messages)
  end

  test "ignores updates without processable messages", %{inbox: inbox} do
    assert {:ok, %{received: 0}} =
             TelegramIngest.perform(%Oban.Job{args: args(inbox.id, %{"update_id" => 9})})

    assert Chatwooter.Repo.aggregate(Message, :count) == 0
  end

  test "enqueues media download for photos", %{account: account, inbox: inbox} do
    tg = Bypass.open()
    s3 = Bypass.open()
    test_pid = self()

    Application.put_env(:chatwooter, :telegram_api_base, "http://localhost:#{tg.port}")

    Application.put_env(:ex_aws, :s3,
      scheme: "http://",
      host: "localhost",
      port: s3.port,
      region: "us-east-1"
    )

    Application.put_env(:ex_aws, :access_key_id, "test")
    Application.put_env(:ex_aws, :secret_access_key, "test")

    Application.put_env(:chatwooter, :storage,
      bucket: "chatwooter-test",
      public_url: "http://localhost:#{s3.port}"
    )

    on_exit(fn ->
      Application.delete_env(:chatwooter, :telegram_api_base)
      Application.delete_env(:ex_aws, :s3)
      Application.delete_env(:ex_aws, :access_key_id)
      Application.delete_env(:ex_aws, :secret_access_key)
      Application.delete_env(:chatwooter, :storage)
    end)

    Bypass.expect_once(tg, "GET", "/bottok/getFile", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(
        200,
        Jason.encode!(%{
          "ok" => true,
          "result" => %{"file_id" => "big", "file_path" => "photos/f1.jpg"}
        })
      )
    end)

    Bypass.expect_once(tg, "GET", "/file/bottok/photos/f1.jpg", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("image/jpeg")
      |> Plug.Conn.resp(200, <<1, 2, 3>>)
    end)

    Bypass.expect_once(s3, fn conn ->
      assert conn.method == "PUT"
      assert String.ends_with?(conn.request_path, "/f1.jpg")
      send(test_pid, {:uploaded, conn.request_path})
      {:ok, _body, conn} = Plug.Conn.read_body(conn)
      Plug.Conn.resp(conn, 200, "")
    end)

    params = %{
      "update_id" => 2,
      "message" => %{
        "message_id" => 43,
        "from" => %{"id" => 111, "first_name" => "Maria"},
        "chat" => %{"id" => 555, "type" => "private"},
        "date" => 1_727_280_001,
        "photo" => [%{"file_id" => "small"}, %{"file_id" => "big"}],
        "caption" => "olha"
      }
    }

    assert {:ok, %{received: 1}} =
             TelegramIngest.perform(%Oban.Job{args: args(inbox.id, params)})

    assert_received {:uploaded, "/chatwooter-test/telegram/" <> _}

    assert [%Message{content: "olha"}] =
             Conversations.list_conversations(account) |> Enum.flat_map(& &1.messages)
  end

  test "cancels jobs for unknown inboxes" do
    assert {:cancel, :inbox_not_found} =
             TelegramIngest.perform(%Oban.Job{args: args(-1, text_params())})
  end
end
