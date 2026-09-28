defmodule Chatwooter.ConversationBulkActionsTest do
  use Chatwooter.DataCase, async: true

  import Chatwooter.AccountsFixtures

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes, Repo}
  alias Chatwooter.Contacts.Label
  alias Chatwooter.Conversations.Conversation

  setup do
    admin = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, admin)
    {:ok, sales} = Inboxes.create_inbox(account, %{name: "Sales", channel_type: "whatsapp"})
    {:ok, support} = Inboxes.create_inbox(account, %{name: "Support", channel_type: "telegram"})

    convs =
      for {inbox, name} <- [{sales, "Ana"}, {sales, "Bia"}, {support, "Caio"}] do
        {:ok, contact} = Contacts.get_or_create_contact(account, %{name: name})
        {:ok, conv} = Conversations.open_conversation(account, inbox, contact, %{source_id: name})
        conv
      end

    %{admin: admin, account: account, sales: sales, support: support, convs: convs}
  end

  defp ids(convs), do: Enum.map(convs, & &1.id)
  defp reload(conv), do: Repo.get!(Conversation, conv.id)

  test "bulk status only touches conversations of the account", ctx do
    other_owner = user_fixture()
    {:ok, other} = Accounts.create_account(%{name: "Other"}, other_owner)
    {:ok, inbox} = Inboxes.create_inbox(other, %{name: "Xinbox", channel_type: "whatsapp"})
    {:ok, contact} = Contacts.get_or_create_contact(other, %{name: "Xavier"})
    {:ok, foreign} = Conversations.open_conversation(other, inbox, contact, %{source_id: "x"})

    assert {:ok, 3} =
             Conversations.bulk_set_status(
               ctx.account,
               ids(ctx.convs) ++ [foreign.id],
               "resolved"
             )

    assert Enum.all?(ctx.convs, &(reload(&1).status == :resolved))
    assert reload(foreign).status == :open
  end

  test "bulk labels add and remove titles on every conversation", ctx do
    Repo.insert!(%Label{account_id: ctx.account.id, title: "billing", color: "#f00"})
    Repo.insert!(%Label{account_id: ctx.account.id, title: "vip", color: "#0f0"})

    assert {:ok, 3} =
             Conversations.bulk_add_labels(ctx.account, ids(ctx.convs), ["billing", "vip"])

    assert Enum.all?(ctx.convs, &(Conversations.list_labels(&1) == ["billing", "vip"]))

    assert {:ok, 3} = Conversations.bulk_remove_labels(ctx.account, ids(ctx.convs), ["billing"])
    assert Enum.all?(ctx.convs, &(Conversations.list_labels(&1) == ["vip"]))

    assert {:error, :not_found} =
             Conversations.bulk_add_labels(ctx.account, ids(ctx.convs), ["nope"])
  end

  test "agents offered for several inboxes are the ones assignable in all of them", ctx do
    both = user_fixture()
    only_sales = user_fixture()

    for user <- [both, only_sales], do: {:ok, _} = Accounts.add_member(ctx.account, user, :agent)
    {:ok, _} = Inboxes.add_member(ctx.account, ctx.sales.id, both.id)
    {:ok, _} = Inboxes.add_member(ctx.account, ctx.support.id, both.id)
    {:ok, _} = Inboxes.add_member(ctx.account, ctx.sales.id, only_sales.id)

    agents =
      Conversations.assignable_agents_for_inboxes(ctx.account, [ctx.sales.id, ctx.support.id])

    assert Enum.sort(Enum.map(agents, & &1.id)) == Enum.sort([ctx.admin.id, both.id])

    assert {:ok, 3} = Conversations.bulk_assign_agent(ctx.account, ids(ctx.convs), both.id)
    assert Enum.all?(ctx.convs, &(reload(&1).assignee_id == both.id))

    assert {:error, :not_assignable} =
             Conversations.bulk_assign_agent(ctx.account, ids(ctx.convs), only_sales.id)

    assert {:ok, 3} = Conversations.bulk_assign_agent(ctx.account, ids(ctx.convs), nil)
    assert Enum.all?(ctx.convs, &is_nil(reload(&1).assignee_id))
  end

  test "bulk team assignment validates the team", ctx do
    {:ok, team} = Accounts.create_team(ctx.account, %{name: "Support"})

    assert {:ok, 3} = Conversations.bulk_assign_team(ctx.account, ids(ctx.convs), team.id)
    assert Enum.all?(ctx.convs, &(reload(&1).team_id == team.id))
    assert {:error, :not_found} = Conversations.bulk_assign_team(ctx.account, ids(ctx.convs), -1)
    assert {:ok, 3} = Conversations.bulk_assign_team(ctx.account, ids(ctx.convs), nil)
  end
end
