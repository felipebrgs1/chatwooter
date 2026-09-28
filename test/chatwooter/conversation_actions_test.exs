defmodule Chatwooter.ConversationActionsTest do
  use Chatwooter.DataCase, async: true

  import Chatwooter.AccountsFixtures

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes, Repo}
  alias Chatwooter.Contacts.{Label, Tag, Tagging}
  alias Chatwooter.Conversations.Conversation

  setup do
    admin = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, admin)
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Sales", channel_type: "whatsapp"})
    {:ok, contact} = Contacts.get_or_create_contact(account, %{name: "Ana"})
    {:ok, conv} = Conversations.open_conversation(account, inbox, contact, %{source_id: "ana"})
    %{admin: admin, account: account, inbox: inbox, conv: conv}
  end

  defp unread(account, conv) do
    account
    |> Conversations.list_conversations([])
    |> Enum.find(&(&1.id == conv.id))
    |> Map.fetch!(:unread_count)
  end

  test "mark_unread brings back the last incoming message as unread", %{account: account} = ctx do
    {:ok, _} = Conversations.add_message(ctx.conv, %{content: "old", message_type: :incoming})
    {:ok, _} = Conversations.mark_seen(ctx.conv)
    assert unread(account, ctx.conv) == 0

    {:ok, _} = Conversations.mark_unread(ctx.conv)
    assert unread(account, ctx.conv) == 1
    assert Conversations.count_unread(ctx.conv) == 1

    {:ok, _} = Conversations.mark_seen(ctx.conv)
    assert unread(account, ctx.conv) == 0
  end

  test "set_priority stores the Rails enum and clears with nil", ctx do
    assert {:ok, %{priority: 3}} = Conversations.set_priority(ctx.conv, "urgent")
    assert {:ok, %{priority: nil}} = Conversations.set_priority(ctx.conv, nil)
    assert {:error, :invalid_priority} = Conversations.set_priority(ctx.conv, "critical")
  end

  test "labels are account labels kept in taggings and cached_label_list", ctx do
    Repo.insert!(%Label{account_id: ctx.account.id, title: "billing", color: "#f00"})
    Repo.insert!(%Label{account_id: ctx.account.id, title: "vip", color: "#0f0"})

    assert {:ok, ["billing"]} = Conversations.add_label(ctx.account, ctx.conv, "billing")
    assert {:ok, ["billing", "vip"]} = Conversations.add_label(ctx.account, ctx.conv, "vip")
    assert {:ok, ["billing", "vip"]} = Conversations.add_label(ctx.account, ctx.conv, "vip")
    assert Repo.get!(Conversation, ctx.conv.id).cached_label_list == "billing, vip"
    assert Conversations.list_labels(ctx.conv) == ["billing", "vip"]

    assert [conv] = Conversations.list_conversations(ctx.account, label: "vip")
    assert conv.id == ctx.conv.id

    assert {:ok, ["vip"]} = Conversations.remove_label(ctx.conv, "billing")
    assert Repo.get!(Conversation, ctx.conv.id).cached_label_list == "vip"
    assert {:error, :not_found} = Conversations.add_label(ctx.account, ctx.conv, "unknown")
  end

  test "agents are assignable only when they belong to the inbox or administer the account",
       ctx do
    member = user_fixture()
    outsider = user_fixture()
    {:ok, _} = Accounts.add_member(ctx.account, member, :agent)
    {:ok, _} = Accounts.add_member(ctx.account, outsider, :agent)
    {:ok, _} = Inboxes.add_member(ctx.account, ctx.inbox.id, member.id)

    ids = ctx.account |> Conversations.assignable_agents(ctx.conv) |> Enum.map(& &1.id)
    assert Enum.sort(ids) == Enum.sort([ctx.admin.id, member.id])

    assert {:ok, %{assignee_id: id}} =
             Conversations.assign_agent(ctx.account, ctx.conv, member.id)

    assert id == member.id

    assert {:error, :not_assignable} =
             Conversations.assign_agent(ctx.account, ctx.conv, outsider.id)

    assert {:ok, %{assignee_id: nil}} = Conversations.assign_agent(ctx.account, ctx.conv, nil)
  end

  test "teams are assignable only within the account", ctx do
    {:ok, team} = Accounts.create_team(ctx.account, %{name: "Support"})
    other_owner = user_fixture()
    {:ok, other} = Accounts.create_account(%{name: "Other"}, other_owner)
    {:ok, foreign} = Accounts.create_team(other, %{name: "Foreign"})

    assert {:ok, %{team_id: id}} = Conversations.assign_team(ctx.account, ctx.conv, team.id)
    assert id == team.id
    assert {:error, :not_found} = Conversations.assign_team(ctx.account, ctx.conv, foreign.id)
    assert {:ok, %{team_id: nil}} = Conversations.assign_team(ctx.account, ctx.conv, nil)
  end

  test "delete_conversation removes messages and label taggings", ctx do
    Repo.insert!(%Label{account_id: ctx.account.id, title: "billing", color: "#f00"})
    {:ok, _} = Conversations.add_label(ctx.account, ctx.conv, "billing")
    {:ok, _} = Conversations.add_message(ctx.conv, %{content: "hi", message_type: :incoming})

    assert {:ok, _} = Conversations.delete_conversation(ctx.conv)
    refute Repo.get(Conversation, ctx.conv.id)
    refute Repo.exists?(from t in Tagging, where: t.taggable_type == "Conversation")
    assert Repo.get_by!(Tag, name: "billing").taggings_count == 0
  end
end
