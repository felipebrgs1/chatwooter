defmodule Chatwooter.ConversationsListTest do
  use Chatwooter.DataCase, async: true

  import Chatwooter.AccountsFixtures

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes, Repo}
  alias Chatwooter.Conversations.Conversation

  setup do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, user)
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})
    %{user: user, account: account, inbox: inbox}
  end

  defp conversation(account, inbox, phone, attrs \\ []) do
    {:ok, contact} =
      Contacts.get_or_create_contact(account, %{
        name: "C #{phone}",
        phone_number: "+55119#{phone}"
      })

    {:ok, conv} = Conversations.open_conversation(account, inbox, contact, %{source_id: phone})
    conv |> Ecto.Changeset.change(attrs) |> Repo.update!()
  end

  defp ids(conversations), do: Enum.map(conversations, & &1.id)

  describe "assignee_type" do
    setup %{user: user, account: account, inbox: inbox} do
      other = user_fixture()

      %{
        mine: conversation(account, inbox, "10000001", assignee_id: user.id),
        others: conversation(account, inbox, "10000002", assignee_id: other.id),
        unassigned: conversation(account, inbox, "10000003")
      }
    end

    test "filters like the Mine / Unassigned / All tabs", %{user: user, account: account} = ctx do
      list = &Conversations.list_conversations(account, assignee_type: &1, user_id: user.id)

      assert ids(list.("me")) == [ctx.mine.id]
      assert ids(list.("unassigned")) == [ctx.unassigned.id]

      assert Enum.sort(ids(list.("all"))) ==
               Enum.sort([ctx.mine.id, ctx.others.id, ctx.unassigned.id])
    end

    test "counts each tab for the same status and inbox", %{user: user, account: account} = ctx do
      assert %{mine: 1, unassigned: 1, all: 3} =
               Conversations.conversation_counts(account, user_id: user.id, status: "open")

      Repo.update!(Ecto.Changeset.change(ctx.others, status: :resolved))

      assert %{mine: 1, unassigned: 1, all: 2} =
               Conversations.conversation_counts(account, user_id: user.id, status: "open")
    end

    test "preloads the assignee", %{user: user, account: account, mine: mine} do
      [conv] = Conversations.list_conversations(account, assignee_type: "me", user_id: user.id)
      assert conv.id == mine.id
      assert conv.assignee.id == user.id
    end
  end

  describe "sort_by" do
    test "orders by last activity, creation and priority", %{account: account, inbox: inbox} do
      now = DateTime.utc_now()

      old =
        conversation(account, inbox, "20000001",
          last_activity_at: DateTime.add(now, -3600),
          priority: 1
        )

      new = conversation(account, inbox, "20000002", last_activity_at: now, priority: nil)

      urgent =
        conversation(account, inbox, "20000003",
          last_activity_at: DateTime.add(now, -60),
          priority: 3
        )

      list = &ids(Conversations.list_conversations(account, sort_by: &1))

      assert list.("last_activity_at_desc") == [new.id, urgent.id, old.id]
      assert list.("last_activity_at_asc") == [old.id, urgent.id, new.id]
      assert list.("created_at_asc") == [old.id, new.id, urgent.id]
      assert list.("created_at_desc") == [urgent.id, new.id, old.id]
      assert list.("priority_desc") == [urgent.id, old.id, new.id]
      assert list.("priority_asc") == [old.id, urgent.id, new.id]
      assert list.("bogus") == list.("last_activity_at_desc")
    end
  end

  describe "unread_count" do
    test "counts incoming messages after the agent last saw it, up to 10", %{
      account: account,
      inbox: inbox
    } do
      conv = conversation(account, inbox, "30000001")
      {:ok, _} = Conversations.add_message(conv, %{content: "oi", message_type: "incoming"})
      {:ok, _} = Conversations.add_message(conv, %{content: "resposta", message_type: "outgoing"})

      assert [%{unread_count: 1}] = Conversations.list_conversations(account)

      {:ok, _} = Conversations.mark_seen(conv)
      assert [%{unread_count: 0}] = Conversations.list_conversations(account)

      for n <- 1..12, do: {:ok, _} = Conversations.add_message(conv, %{content: "#{n}"})
      assert [%{unread_count: 10}] = Conversations.list_conversations(account)
    end

    test "sort_by unread puts unread conversations first", %{account: account, inbox: inbox} do
      read = conversation(account, inbox, "30000002", last_activity_at: DateTime.utc_now())
      unread = conversation(account, inbox, "30000003")
      {:ok, _} = Conversations.add_message(unread, %{content: "oi"})
      {:ok, _} = Conversations.add_message(read, %{content: "oi"})
      {:ok, _} = Conversations.mark_seen(read)

      assert [%Conversation{id: first} | _] =
               Conversations.list_conversations(account, sort_by: "unread")

      assert first == unread.id
    end
  end
end
