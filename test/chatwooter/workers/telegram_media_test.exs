defmodule Chatwooter.Workers.TelegramMediaTest do
  @moduledoc "Download de mídia do Telegram + upload p/ RustFS (fila `webhook_ingest`)."
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes}
  alias Chatwooter.Conversations.Attachment
  alias Chatwooter.Workers.TelegramMedia

  setup do
    tg = Bypass.open()
    s3 = Bypass.open()

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

    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)

    {:ok, inbox} =
      Inboxes.create_inbox(account, %{
        name: "TG",
        channel_type: "telegram",
        provider_config: %{"bot_token" => "test-token"}
      })

    {:ok, contact} = Contacts.get_or_create_contact(account, %{name: "Maria"})
    {:ok, conv} = Conversations.open_conversation(account, inbox, contact, %{source_id: "555"})

    {:ok, message} =
      Conversations.add_message(conv, %{
        content: nil,
        content_type: "image",
        message_type: "incoming",
        source_id: "43"
      })

    %{tg: tg, s3: s3, account: account, message: message}
  end

  defp stub_download(tg) do
    Bypass.expect_once(tg, "GET", "/bottest-token/getFile", fn conn ->
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

    Bypass.expect_once(tg, "GET", "/file/bottest-token/photos/f1.jpg", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("image/jpeg")
      |> Plug.Conn.resp(200, <<1, 2, 3>>)
    end)
  end

  defp stub_upload(s3, key) do
    Bypass.expect_once(s3, "PUT", "/chatwooter-test/#{key}", fn conn ->
      {:ok, _body, conn} = Plug.Conn.read_body(conn)
      Plug.Conn.resp(conn, 200, "")
    end)
  end

  test "downloads, uploads and links the attachment", %{
    tg: tg,
    s3: s3,
    account: account,
    message: message
  } do
    Phoenix.PubSub.subscribe(Chatwooter.PubSub, "account:#{account.id}")
    stub_download(tg)

    key = "telegram/#{account.id}/#{message.id}/f1.jpg"
    stub_upload(s3, key)

    assert {:ok, %{key: ^key}} =
             TelegramMedia.perform(%Oban.Job{
               args: %{"message_id" => message.id, "file_id" => "big"}
             })

    assert_received {:message_updated, _}
    assert [%Attachment{key: ^key, url: url}] = Conversations.list_attachments(message)
    assert url =~ "f1.jpg"
  end

  test "cancels when already stored", %{account: account, message: message} do
    {:ok, _} =
      Conversations.create_attachment(message, %{
        file_type: "image",
        key: "telegram/#{account.id}/#{message.id}/f1.jpg",
        url: "http://x/f1.jpg"
      })

    # Sem stubs: qualquer HTTP derruba o teste.
    assert {:cancel, :already_stored} =
             TelegramMedia.perform(%Oban.Job{
               args: %{"message_id" => message.id, "file_id" => "big"}
             })
  end

  test "cancels unknown messages" do
    assert {:cancel, :not_found} =
             TelegramMedia.perform(%Oban.Job{args: %{"message_id" => -1, "file_id" => "big"}})
  end
end
