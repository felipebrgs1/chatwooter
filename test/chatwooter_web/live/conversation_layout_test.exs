defmodule ChatwooterWeb.ConversationLayoutTest do
  use ChatwooterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures
  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes, Repo}
  alias Chatwooter.Accounts.User

  setup %{conn: conn} do
    admin = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Layout"}, admin)
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Sales", channel_type: "whatsapp"})
    {:ok, contact} = Contacts.get_or_create_contact(account, %{name: "Ana"})
    {:ok, conv} = Conversations.open_conversation(account, inbox, contact, %{source_id: "ana"})
    {:ok, _} = Conversations.add_message(conv, %{content: "hello there", message_type: :incoming})
    Repo.insert!(%Contacts.Label{account_id: account.id, title: "vip", color: "#0f0"})
    {:ok, _} = Conversations.add_label(account, conv, "vip")

    %{conn: log_in_user(conn, admin), admin: admin, conv: conv}
  end

  test "the header button switches to the expanded layout and saves it", ctx do
    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    assert has_element?(lv, "#conversation-list[data-layout=condensed]")
    assert has_element?(lv, "#conversation-view")

    lv |> element("#switch-view-layout") |> render_click()
    assert has_element?(lv, "#conversation-list[data-layout=expanded]")
    refute has_element?(lv, "#conversation-view")

    settings = Repo.get!(User, ctx.admin.id).ui_settings
    assert settings["conversation_display_type"] == "expanded"
    assert settings["previously_used_conversation_display_type"] == "expanded"

    lv |> element("#switch-view-layout") |> render_click()
    assert has_element?(lv, "#conversation-list[data-layout=condensed]")
    assert Repo.get!(User, ctx.admin.id).ui_settings["conversation_display_type"] == "condensed"
  end

  test "expanded rows show the table columns of ConversationCardExpanded", ctx do
    {:ok, _} =
      Accounts.update_ui_settings(ctx.admin, %{"conversation_display_type" => "expanded"})

    {:ok, lv, _} = live(ctx.conn, ~p"/app")
    lv |> element("#chat-tab-all") |> render_click()

    row = "#conv-#{ctx.conv.id}"
    assert has_element?(lv, "#{row}[data-layout=expanded]")
    assert has_element?(lv, "#{row} [data-role=status][title=open]")
    assert has_element?(lv, "#{row} [data-role=priority][title=None]")
    assert has_element?(lv, "#{row} [data-role=id]", "#{ctx.conv.display_id}")
    assert has_element?(lv, "#{row} h4", "Ana")
    assert has_element?(lv, "#{row} [data-role=preview]", "hello there")
    assert has_element?(lv, "#{row} [data-role=unread]", "1")
    assert has_element?(lv, "#{row} [data-label]", "vip")
    assert has_element?(lv, "#{row}-select")
  end

  test "an opened conversation takes the whole area with a back link", ctx do
    {:ok, _} =
      Accounts.update_ui_settings(ctx.admin, %{"conversation_display_type" => "expanded"})

    {:ok, lv, _} = live(ctx.conn, ~p"/app?conversation_id=#{ctx.conv.id}")

    assert has_element?(lv, "#conversation-list[hidden]")
    assert has_element?(lv, "#conversation-view")
    lv |> element("#conversation-back") |> render_click()
    assert_patch(lv, ~p"/app")
    assert has_element?(lv, "#conversation-list[data-layout=expanded]")
  end
end
