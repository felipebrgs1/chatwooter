defmodule Chatwooter.Channels.Telegram.BotApiTest do
  @moduledoc "Adapter Telegram Bot API: parse de webhook + envio (Fase 2)."
  use ExUnit.Case, async: false

  import Plug.Conn, only: [put_req_header: 3]
  import Plug.Test

  alias Chatwooter.Channels.Telegram.BotApi
  alias Chatwooter.Inboxes.Inbox

  setup do
    bypass = Bypass.open()

    Application.put_env(:chatwooter, :telegram_api_base, "http://localhost:#{bypass.port}")

    on_exit(fn -> Application.delete_env(:chatwooter, :telegram_api_base) end)

    %{bypass: bypass}
  end

  defp inbox(extra_config \\ %{}) do
    %Inbox{
      channel_type: :telegram,
      provider_config: Map.merge(%{"bot_token" => "test-token"}, extra_config)
    }
  end

  describe "parse_webhook/1" do
    test "normalizes a text message" do
      params = %{
        "update_id" => 123,
        "message" => %{
          "message_id" => 42,
          "from" => %{"id" => 111, "first_name" => "Maria", "username" => "maria_s"},
          "chat" => %{"id" => 555, "type" => "private"},
          "date" => 1_727_280_000,
          "text" => "Olá"
        }
      }

      assert {:ok,
              [
                %{
                  channel: :telegram,
                  source_id: "555",
                  sender_name: "Maria",
                  type: :text,
                  content: "Olá",
                  external_id: "42"
                }
              ]} = BotApi.parse_webhook(params)
    end

    test "normalizes a photo taking the biggest file" do
      params = %{
        "update_id" => 124,
        "message" => %{
          "message_id" => 43,
          "from" => %{"id" => 111, "first_name" => "Maria"},
          "chat" => %{"id" => 555, "type" => "private"},
          "date" => 1_727_280_001,
          "photo" => [%{"file_id" => "small"}, %{"file_id" => "big"}],
          "caption" => "olha isso"
        }
      }

      assert {:ok,
              [
                %{
                  channel: :telegram,
                  source_id: "555",
                  type: :image,
                  content: "olha isso",
                  file_id: "big",
                  external_id: "43"
                }
              ]} = BotApi.parse_webhook(params)
    end

    test "ignores unsupported updates" do
      assert {:ok, []} = BotApi.parse_webhook(%{"update_id" => 1, "poll_answer" => %{}})
      assert {:ok, []} = BotApi.parse_webhook(%{"update_id" => 2})
    end
  end

  describe "send_message/2" do
    test "posts text to sendMessage and returns the external id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/bottest-token/sendMessage", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert %{"chat_id" => "555", "text" => "Oi"} = Jason.decode!(body)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 99}})
        )
      end)

      assert {:ok, %{external_id: "99"}} =
               BotApi.send_message(inbox(), %{to: "555", content: "Oi"})
    end

    test "returns error when telegram rejects the message", %{bypass: bypass} do
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

      assert {:error, %{description: "Bad Request: chat not found"}} =
               BotApi.send_message(inbox(), %{to: "555", content: "Oi"})
    end

    test "returns error without bot_token" do
      inbox = %Inbox{channel_type: :telegram, provider_config: %{}}

      assert {:error, :missing_bot_token} =
               BotApi.send_message(inbox, %{to: "555", content: "Oi"})
    end
  end

  describe "download_file/2" do
    test "downloads bytes via getFile", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/bottest-token/getFile", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["file_id"] == "big"

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

      Bypass.expect_once(bypass, "GET", "/file/bottest-token/photos/f1.jpg", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("image/jpeg")
        |> Plug.Conn.resp(200, <<1, 2, 3>>)
      end)

      assert {:ok, %{bytes: <<1, 2, 3>>, content_type: "image/jpeg"}} =
               BotApi.download_file(inbox(), "big")
    end

    test "returns error when getFile fails", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/bottest-token/getFile", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{"ok" => false, "error_code" => 400, "description" => "Bad Request"})
        )
      end)

      assert {:error, %{description: "Bad Request"}} =
               BotApi.download_file(inbox(), "nope")
    end

    test "returns error without bot_token" do
      inbox = %Inbox{channel_type: :telegram, provider_config: %{}}
      assert {:error, :missing_bot_token} = BotApi.download_file(inbox, "big")
    end
  end

  describe "validate_webhook/2" do
    test "accepts when the secret token matches" do
      conn =
        conn(:post, "/")
        |> put_req_header("x-telegram-bot-api-secret-token", "s3cr3t")

      assert :ok = BotApi.validate_webhook(conn, inbox(%{"webhook_secret" => "s3cr3t"}))
    end

    test "rejects when the secret token mismatches" do
      conn =
        conn(:post, "/")
        |> put_req_header("x-telegram-bot-api-secret-token", "wrong")

      assert {:error, :unauthorized} =
               BotApi.validate_webhook(conn, inbox(%{"webhook_secret" => "s3cr3t"}))
    end

    test "accepts when the inbox has no secret configured yet" do
      assert :ok = BotApi.validate_webhook(conn(:post, "/"), inbox())
    end
  end
end
