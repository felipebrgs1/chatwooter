defmodule Chatwooter.StorageTest do
  @moduledoc "Upload p/ object storage S3-compatível (Bypass no lugar do RustFS)."
  use ExUnit.Case, async: false

  alias Chatwooter.Storage

  setup do
    bypass = Bypass.open()
    port = bypass.port

    Application.put_env(:ex_aws, :s3,
      scheme: "http://",
      host: "localhost",
      port: port,
      region: "us-east-1"
    )

    Application.put_env(:ex_aws, :access_key_id, "test")
    Application.put_env(:ex_aws, :secret_access_key, "test")

    Application.put_env(:chatwooter, :storage,
      bucket: "chatwooter-test",
      public_url: "http://localhost:#{port}"
    )

    on_exit(fn ->
      Application.delete_env(:ex_aws, :s3)
      Application.delete_env(:ex_aws, :access_key_id)
      Application.delete_env(:ex_aws, :secret_access_key)
      Application.delete_env(:chatwooter, :storage)
    end)

    %{bypass: bypass, port: port}
  end

  test "uploads bytes and returns key + public url", %{bypass: bypass, port: port} do
    key = "telegram/1/9/f1.jpg"

    Bypass.expect_once(bypass, "PUT", "/chatwooter-test/#{key}", fn conn ->
      assert Plug.Conn.get_req_header(conn, "content-type") == ["image/jpeg"]
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert byte_size(body) == 3

      Plug.Conn.resp(conn, 200, "")
    end)

    assert {:ok, %{key: ^key, size_bytes: 3, content_type: "image/jpeg"}} =
             Storage.put_object(key, <<1, 2, 3>>, content_type: "image/jpeg")

    assert Storage.public_url(key) ==
             "http://localhost:#{port}/chatwooter-test/#{key}"
  end

  test "returns error on storage failure", %{bypass: bypass} do
    # ex_aws retenta 5xx sozinho: stub (n) em vez de expect_once.
    Bypass.expect(bypass, "PUT", "/chatwooter-test/boom.jpg", fn conn ->
      Plug.Conn.resp(conn, 500, "boom")
    end)

    assert {:error, %{code: 500}} = Storage.put_object("boom.jpg", <<1>>)
  end
end
