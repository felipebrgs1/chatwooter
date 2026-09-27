defmodule ChatwooterWeb.FaviconTest do
  use ChatwooterWeb.ConnCase, async: true

  defp favicon_hrefs(html) do
    html
    |> LazyHTML.from_document()
    |> LazyHTML.query(~s(link[rel="icon"]))
    |> LazyHTML.attribute("href")
  end

  test "auth pages ship the Chatwoot favicons", %{conn: conn} do
    html = conn |> get(~p"/app/login") |> html_response(200)

    assert "/images/favicon-32x32.png" in favicon_hrefs(html)
  end

  describe "dashboard" do
    setup :register_and_log_in_user

    test "ships the Chatwoot favicons", %{conn: conn} do
      html = conn |> get(~p"/app") |> html_response(200)

      assert "/images/favicon-32x32.png" in favicon_hrefs(html)
    end
  end

  test "favicon files are served", %{conn: conn} do
    for size <- ~w(16x16 32x32 96x96) do
      assert conn |> get("/images/favicon-#{size}.png") |> response(200)
    end
  end
end
