defmodule ChatwooterWeb.ConversationBulkActionsTest do
  use ChatwooterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Chatwooter.AccountsFixtures
  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes, Repo}
  alias Chatwooter.Conversations.Conversation

  setup %{conn: conn} do
    admin = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Bulk"}, admin)
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Sales", channel_type: "whatsapp"})

    [one, two] =
      for name <- ["Ana", "Bia"] do
        {:ok, contact} = Contacts.get_or_create_contact(account, %{name: name})
        {:ok, conv} = Conversations.open_conversation(account, inbox, contact, %{source_id: name})
        conv
      end

    {:ok, lv, _} = live(log_in_user(conn, admin), ~p"/app")
    lv |> element("#chat-tab-all") |> render_click()
    %{lv: lv, admin: admin, account: account, one: one, two: two}
  end

  defp select(lv, conv),
    do: lv |> element("#conv-#{conv.id}-select") |> render_hook("bulk:toggle", %{"id" => conv.id})

  defp reload(conv), do: Repo.get!(Conversation, conv.id)

  test "selecting cards shows the bar; select all and clear", %{lv: lv} = ctx do
    refute has_element?(lv, "#bulk-actions")
    select(lv, ctx.one)
    assert has_element?(lv, "#bulk-actions", "1 selected")
    assert has_element?(lv, "#conv-#{ctx.one.id}.selected")
    refute has_element?(lv, "#bulk-all-selected-alert")

    lv |> element("#bulk-select-all") |> render_click()
    assert has_element?(lv, "#bulk-actions", "2 selected")

    assert has_element?(
             lv,
             "#bulk-all-selected-alert",
             "Conversations visible on this page are only selected."
           )

    lv |> element("#bulk-clear") |> render_click()
    refute has_element?(lv, "#bulk-actions")
    refute has_element?(lv, "#conv-#{ctx.one.id}.selected")

    select(lv, ctx.one)
    select(lv, ctx.one)
    refute has_element?(lv, "#bulk-actions")
  end

  test "status menu resolves the selection and clears it", %{lv: lv} = ctx do
    select(lv, ctx.one)
    select(lv, ctx.two)
    lv |> element("#bulk-status") |> render_click()
    refute has_element?(lv, "#bulk-status-open")
    lv |> element("#bulk-status-resolved") |> render_click()

    assert reload(ctx.one).status == :resolved
    assert reload(ctx.two).status == :resolved
    assert render(lv) =~ "Conversation status updated successfully."
    refute has_element?(lv, "#bulk-actions")
  end

  test "labels are chosen, then assigned and removed", %{lv: lv} = ctx do
    label = Repo.insert!(%Contacts.Label{account_id: ctx.account.id, title: "vip", color: "#0f0"})
    select(lv, ctx.one)
    select(lv, ctx.two)

    lv |> element("#bulk-assign-labels") |> render_click()
    assert has_element?(lv, "#bulk-apply-labels[disabled]", "Assign selected labels")
    lv |> element("#bulk-label-#{label.id}") |> render_click()
    assert has_element?(lv, "#bulk-label-#{label.id} .ph-check")
    lv |> element("#bulk-apply-labels") |> render_click()

    assert Conversations.list_labels(ctx.one) == ["vip"]
    assert Conversations.list_labels(ctx.two) == ["vip"]
    assert render(lv) =~ "Labels assigned successfully."

    select(lv, ctx.one)
    lv |> element("#bulk-remove-labels") |> render_click()
    lv |> element("#bulk-label-#{label.id}") |> render_click()
    lv |> element("#bulk-apply-labels", "Remove selected labels") |> render_click()
    assert Conversations.list_labels(ctx.one) == []
    assert Conversations.list_labels(ctx.two) == ["vip"]
  end

  test "remove labels only lists labels applied to the selection", %{lv: lv} = ctx do
    vip = Repo.insert!(%Contacts.Label{account_id: ctx.account.id, title: "vip", color: "#0f0"})

    other =
      Repo.insert!(%Contacts.Label{account_id: ctx.account.id, title: "misc", color: "#00f"})

    {:ok, _} = Conversations.add_label(ctx.account, ctx.one, "vip")

    select(lv, ctx.one)
    lv |> element("#bulk-remove-labels") |> render_click()
    assert has_element?(lv, "#bulk-label-#{vip.id}")
    refute has_element?(lv, "#bulk-label-#{other.id}")
  end

  test "agent assignment asks for confirmation", %{lv: lv} = ctx do
    select(lv, ctx.one)
    select(lv, ctx.two)
    lv |> element("#bulk-agent") |> render_click()
    lv |> element("#bulk-agent-#{ctx.admin.id}") |> render_click()

    assert has_element?(
             lv,
             "#bulk-confirmation",
             "Are you sure you want to assign 2 conversations to #{ctx.admin.email}?"
           )

    lv |> element("#bulk-cancel") |> render_click()
    refute has_element?(lv, "#bulk-confirmation")
    assert reload(ctx.one).assignee_id == nil

    lv |> element("#bulk-agent-#{ctx.admin.id}") |> render_click()
    lv |> element("#bulk-confirm") |> render_click()
    assert reload(ctx.one).assignee_id == ctx.admin.id
    assert reload(ctx.two).assignee_id == ctx.admin.id
    assert render(lv) =~ "Conversations assigned successfully."
  end

  test "team assignment and unassignment", %{lv: lv} = ctx do
    {:ok, team} = Accounts.create_team(ctx.account, %{name: "Support"})
    select(lv, ctx.one)
    lv |> element("#bulk-team") |> render_click()
    lv |> element("#bulk-team-#{team.id}") |> render_click()
    assert has_element?(lv, "#bulk-confirmation", "assign 1 conversation to Support?")
    lv |> element("#bulk-confirm") |> render_click()
    assert reload(ctx.one).team_id == team.id

    select(lv, ctx.one)
    lv |> element("#bulk-team") |> render_click()
    lv |> element("#bulk-team-none") |> render_click()

    assert has_element?(
             lv,
             "#bulk-confirmation",
             "Are you sure you want to unassign 1 conversation?"
           )

    lv |> element("#bulk-confirm") |> render_click()
    assert reload(ctx.one).team_id == nil
  end
end
