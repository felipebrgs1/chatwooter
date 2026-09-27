defmodule ChatwooterWeb.SidebarTest do
  use ChatwooterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures

  alias Chatwooter.{Accounts, Inboxes}

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, user)
    %{conn: log_in_user(conn, user), user: user, account: account}
  end

  test "shows account, navigation groups and the current user", %{conn: conn, user: user} do
    {:ok, lv, _html} = live(conn, ~p"/app")

    assert has_element?(lv, "#sidebar-account-switcher", "Acme")

    for group <- ~w(conversation contacts companies settings) do
      assert has_element?(lv, "#sidebar-group-#{group}")
    end

    assert has_element?(lv, "#sidebar-profile-menu-trigger", user.email)
    assert has_element?(lv, "#sidebar-profile-menu a[href='/app/settings/profile']")
    assert has_element?(lv, "#sidebar-profile-menu a[href='/app/logout'][data-method=delete]")
  end

  test "expands only the group of the current page and marks the active leaf", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app")

    assert has_element?(lv, "#sidebar-group-conversation[data-expanded=true]")
    assert has_element?(lv, "#sidebar-group-contacts[data-expanded=false]")
    assert has_element?(lv, "#sidebar-all-conversations[aria-current=page]")

    {:ok, lv, _html} = live(conn, ~p"/app/contacts")

    assert has_element?(lv, "#sidebar-group-contacts[data-expanded=true]")
    assert has_element?(lv, "#sidebar-group-conversation[data-expanded=false]")
    assert has_element?(lv, "#sidebar-all-contacts[aria-current=page]")
    refute has_element?(lv, "#sidebar-all-conversations[aria-current=page]")
  end

  test "picks the most specific settings leaf", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app/settings/inboxes")

    assert has_element?(lv, "#sidebar-settings-inboxes[aria-current=page]")
    refute has_element?(lv, "#sidebar-settings-account[aria-current=page]")

    {:ok, lv, _html} = live(conn, ~p"/app/settings/profile")
    refute has_element?(lv, "#sidebar-group-settings [aria-current=page]")
  end

  test "lists inboxes under channels only when there are any", %{conn: conn, account: account} do
    {:ok, lv, _html} = live(conn, ~p"/app")
    refute has_element?(lv, "#sidebar-section-channels")

    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "telegram"})
    {:ok, lv, _html} = live(conn, ~p"/app?inbox_id=#{inbox.id}")

    assert has_element?(lv, "#sidebar-section-channels #sidebar-inbox-#{inbox.id}", "Vendas")
    assert has_element?(lv, "#sidebar-inbox-#{inbox.id}[aria-current=page]")
    refute has_element?(lv, "#sidebar-all-conversations[aria-current=page]")
  end

  test "changes the agent availability from the profile menu", %{
    conn: conn,
    user: user,
    account: account
  } do
    {:ok, lv, _html} = live(conn, ~p"/app/contacts")
    assert has_element?(lv, "#sidebar-profile-menu-trigger [data-status=online]")

    lv |> element("#sidebar-availability-busy") |> render_click()

    assert has_element?(lv, "#sidebar-profile-menu-trigger [data-status=busy]")
    assert Accounts.get_membership(account, user).availability == :busy

    lv |> element("#sidebar-auto-offline") |> render_click()
    refute Accounts.get_membership(account, user).auto_offline
  end

  describe "collapsed sidebar" do
    setup %{user: user} do
      {:ok, user} = Accounts.update_ui_settings(user, %{"sidebar_width" => 56})
      %{user: user}
    end

    test "renders icon triggers with hover popovers instead of the tree", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app/contacts")

      assert has_element?(lv, "#app-sidebar[data-collapsed=true]")
      assert has_element?(lv, "#sidebar-group-contacts [data-popover-trigger=contacts]")
      assert has_element?(lv, "#sidebar-popover-contacts a[href='/app/contacts']", "All Contacts")
      assert has_element?(lv, "#sidebar-popover-contacts a[aria-current=page]")
      refute has_element?(lv, "#sidebar-all-contacts")
      refute has_element?(lv, "#sidebar-profile-menu-trigger", "@")
    end

    test "lists the user's accounts in the logo switcher", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app")
      assert has_element?(lv, "#sidebar-account-menu-body", "Acme")
    end

    test "shows the expanded sidebar on mobile", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app")
      lv |> element("#app-sidebar") |> render_hook("sidebar:viewport", %{"mobile" => true})

      assert has_element?(lv, "#app-sidebar[data-collapsed=false]")
      assert has_element?(lv, "#sidebar-all-conversations")
    end

    test "double click on the handle expands and persists", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/app")
      lv |> element("#app-sidebar") |> render_hook("sidebar:toggle_collapse", %{})

      assert has_element?(lv, "#app-sidebar[data-collapsed=false]")
      assert Accounts.get_user!(user.id).ui_settings["sidebar_width"] == 200
    end
  end

  describe "resizing" do
    test "clamps the width and snaps to collapsed below the threshold on release", %{
      conn: conn,
      user: user
    } do
      {:ok, lv, _html} = live(conn, ~p"/app")
      sidebar = element(lv, "#app-sidebar")

      render_hook(sidebar, "sidebar:resize", %{"width" => 999, "save" => true})
      assert has_element?(lv, "#app-sidebar[style*='--sidebar-width: 320px']")
      assert Accounts.get_user!(user.id).ui_settings["sidebar_width"] == 320

      render_hook(sidebar, "sidebar:resize", %{"width" => 150})
      assert has_element?(lv, "#app-sidebar[data-collapsed=true]")
      assert Accounts.get_user!(user.id).ui_settings["sidebar_width"] == 320

      render_hook(sidebar, "sidebar:resize", %{"width" => 150, "save" => true})
      assert has_element?(lv, "#app-sidebar[style*='--sidebar-width: 56px']")
      assert Accounts.get_user!(user.id).ui_settings["sidebar_width"] == 56
    end
  end

  test "mobile launcher is hidden while a conversation is open", %{conn: conn, account: account} do
    {:ok, lv, _html} = live(conn, ~p"/app")
    assert has_element?(lv, "#mobile-sidebar-launcher")

    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    {:ok, contact} =
      Chatwooter.Contacts.get_or_create_contact(account, %{
        name: "Ana",
        phone_number: "+5511900000001"
      })

    {:ok, conv} =
      Chatwooter.Conversations.open_conversation(account, inbox, contact, %{
        source_id: "5511900000001"
      })

    {:ok, lv, _html} = live(conn, ~p"/app?conversation_id=#{conv.id}")
    refute has_element?(lv, "#mobile-sidebar-launcher")
  end
end
