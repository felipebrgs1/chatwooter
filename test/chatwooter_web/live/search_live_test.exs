defmodule ChatwooterWeb.SearchLiveTest do
  @moduledoc "Busca global — port de `modules/search/components/SearchView.vue`."
  use ChatwooterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes}

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, user)
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})
    %{conn: log_in_user(conn, user), user: user, account: account, inbox: inbox}
  end

  defp contact(account, name, attrs \\ %{}) do
    {:ok, contact} =
      Contacts.create_contact(
        account,
        Map.merge(
          %{name: name, phone_number: "+55119#{System.unique_integer([:positive])}"},
          attrs
        )
      )

    contact
  end

  defp conversation(account, inbox, contact) do
    {:ok, conv} = Conversations.open_conversation(account, inbox, contact)
    conv
  end

  defp search(lv, q), do: lv |> form("#search-form", %{q: q}) |> render_change()

  test "redirects guests to login" do
    assert {:error, {:redirect, %{to: "/app/login"}}} = live(build_conn(), ~p"/app/search")
  end

  test "the sidebar search button links to the search page", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app")
    assert has_element?(lv, "a#sidebar-search[href='/app/search']")
  end

  test "shows the default empty state without a query", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app/search")

    assert has_element?(lv, "#search-input[placeholder='Type 3 or more characters to search']")
    assert has_element?(lv, "#search-empty-default", "Search by conversation id")
    assert has_element?(lv, "#search-back[href='/app']")
    refute has_element?(lv, "#search-tabs")
  end

  test "searches contacts, messages and conversations and patches the URL", %{
    conn: conn,
    account: account,
    inbox: inbox
  } do
    maria = contact(account, "Maria Silva", %{email: "maria@acme.com"})
    conv = conversation(account, inbox, maria)
    {:ok, message} = Conversations.add_message(conv, %{content: "Oi, sou a Maria"})
    _other = contact(account, "João")

    {:ok, lv, _html} = live(conn, ~p"/app/search")
    search(lv, "maria")

    assert_patch(lv, ~p"/app/search?q=maria")

    assert has_element?(lv, "#search-tabs-all", "All results")
    assert has_element?(lv, "#search-tabs-contacts", "Contacts (1)")
    assert has_element?(lv, "#search-tabs-messages", "Messages (1)")
    assert has_element?(lv, "#search-tabs-conversations", "Conversations (1)")

    assert has_element?(lv, "#search-contact-#{maria.id}[href='/app/contacts/#{maria.id}']")
    assert has_element?(lv, "#search-contact-#{maria.id}", "maria@acme.com")

    assert has_element?(
             lv,
             "#search-conversation-#{conv.id}[href='/app?conversation_id=#{conv.id}']",
             "Maria Silva"
           )

    assert has_element?(lv, "#search-conversation-#{conv.id}", "Vendas")
    assert has_element?(lv, "#search-message-#{message.id}", "Maria Silva wrote:")
    assert has_element?(lv, "#search-message-#{message.id} span.searchkey--highlight", "Maria")
    refute render(lv) =~ "João"
  end

  test "runs the search from the URL and filters by tab", %{conn: conn, account: account} do
    maria = contact(account, "Maria Silva")

    {:ok, lv, _html} = live(conn, ~p"/app/search?q=maria")
    assert has_element?(lv, "#search-contact-#{maria.id}")
    assert has_element?(lv, "#search-messages")

    lv |> element("#search-tabs-contacts") |> render_click()
    assert_patch(lv, ~p"/app/search?q=maria&tab=contacts")

    assert has_element?(lv, "#search-tabs-contacts[aria-selected=true]")
    assert has_element?(lv, "#search-contact-#{maria.id}")
    refute has_element?(lv, "#search-messages")
    refute has_element?(lv, "#search-conversations")
  end

  test "shows the full empty state when nothing matches", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app/search?q=nothing")

    assert has_element?(lv, "#search-empty", "No results found for query 'nothing'")
  end

  test "shows the per-section empty state on a specific tab", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app/search?q=nothing&tab=messages")

    assert has_element?(lv, "#search-messages", "No messages found for query 'nothing'")
  end

  test "ignores single-character queries (unless numeric)", %{conn: conn, account: account} do
    contact(account, "Maria Silva")

    {:ok, lv, _html} = live(conn, ~p"/app/search")
    search(lv, "m")

    assert has_element?(lv, "#search-empty-default")
    refute has_element?(lv, "#search-tabs")
  end

  test "view more switches to the tab and load more fetches the next page", %{
    conn: conn,
    account: account
  } do
    for i <- 1..16, do: contact(account, "Page #{i}")

    {:ok, lv, _html} = live(conn, ~p"/app/search?q=page")
    assert has_element?(lv, "#search-tabs-contacts", "Contacts (15)")
    # a aba All mostra só 5 por seção
    assert lv |> element("#search-contacts") |> render() |> count_items() == 5
    refute has_element?(lv, "#search-load-more")

    lv |> element("#search-view-more-contacts") |> render_click()
    assert_patch(lv, ~p"/app/search?q=page&tab=contacts")
    assert lv |> element("#search-contacts") |> render() |> count_items() == 15

    lv |> element("#search-load-more") |> render_click()
    assert lv |> element("#search-contacts") |> render() |> count_items() == 16
    assert has_element?(lv, "#search-tabs-contacts", "Contacts (16)")
    refute has_element?(lv, "#search-load-more")
  end

  defp count_items(html) do
    html |> LazyHTML.from_fragment() |> LazyHTML.query("a[id^=search-contact-]") |> Enum.count()
  end

  describe "recent searches" do
    test "remembers the last 3 searches in ui_settings", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/app/search")

      for q <- ~w(alpha beta gamma delta), do: search(lv, q)
      search(lv, "BETA")

      assert Accounts.get_user!(user.id).ui_settings["recent_searches"] ==
               ["BETA", "delta", "gamma"]

      {:ok, lv, _html} = live(conn, ~p"/app/search")
      assert has_element?(lv, "#recent-searches", "Recent searches")
      assert has_element?(lv, "#recent-search-0", "BETA")
      assert has_element?(lv, "#recent-search-0", "Most recent")
      assert has_element?(lv, "#recent-search-2", "gamma")
    end

    test "selecting one runs it; clear all forgets them", %{
      conn: conn,
      user: user,
      account: account
    } do
      maria = contact(account, "Maria Silva")
      Accounts.update_ui_settings(user, %{"recent_searches" => ["maria"]})

      {:ok, lv, _html} = live(conn, ~p"/app/search")
      lv |> element("#recent-search-0") |> render_click()

      assert_patch(lv, ~p"/app/search?q=maria")
      assert_push_event(lv, "search:set-query", %{q: "maria"})
      assert has_element?(lv, "#search-contact-#{maria.id}")

      lv |> element("#recent-searches-clear") |> render_click()
      refute has_element?(lv, "#recent-searches")
      assert Accounts.get_user!(user.id).ui_settings["recent_searches"] == []
    end
  end
end
