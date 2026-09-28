defmodule ChatwooterWeb.ConversationCardLabelsTest do
  use ChatwooterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures
  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes, Repo}

  setup %{conn: conn} do
    admin = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Labels"}, admin)
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Sales", channel_type: "whatsapp"})
    {:ok, contact} = Contacts.get_or_create_contact(account, %{name: "Ana"})
    {:ok, conv} = Conversations.open_conversation(account, inbox, contact, %{source_id: "ana"})

    for {title, color} <- [{"vip", "#00ff00"}, {"billing", "#ff0000"}, {"unused", "#0000ff"}] do
      Repo.insert!(%Contacts.Label{
        account_id: account.id,
        title: title,
        color: color,
        description: "#{title} customers"
      })
    end

    %{conn: log_in_user(conn, admin), account: account, conv: conv}
  end

  test "cards show the conversation labels in account order", ctx do
    {:ok, _} = Conversations.add_label(ctx.account, ctx.conv, "billing")
    {:ok, _} = Conversations.add_label(ctx.account, ctx.conv, "vip")
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#chat-tab-all") |> render_click()

    labels = "#conv-#{ctx.conv.id}-labels [data-label]"
    assert has_element?(lv, "#{labels}[title='vip customers']", "vip")
    assert has_element?(lv, "#{labels} span[style*='#ff0000']")
    refute has_element?(lv, labels, "unused")

    titles =
      lv
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query(labels)
      |> Enum.map(&LazyHTML.text/1)
      |> Enum.map(&String.trim/1)

    assert titles == ["vip", "billing"]
  end

  test "cards without labels have no label row", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#chat-tab-all") |> render_click()
    assert has_element?(lv, "#conv-#{ctx.conv.id}")
    refute has_element?(lv, "#conv-#{ctx.conv.id}-labels")
  end

  test "the card updates when a label is added from the context menu", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#chat-tab-all") |> render_click()
    {:ok, _} = Conversations.add_label(ctx.account, ctx.conv, "vip")
    assert has_element?(lv, "#conv-#{ctx.conv.id}-labels", "vip")
  end
end
