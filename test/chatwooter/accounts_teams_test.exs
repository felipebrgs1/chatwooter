defmodule Chatwooter.AccountsTeamsTest do
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Inboxes}
  alias Chatwooter.Accounts.{Team, TeamMember}
  alias Chatwooter.Inboxes.InboxMember
  alias Chatwooter.SchemaParity

  @schema Path.expand("../../chatwoot/db/schema.rb", __DIR__)

  setup do
    owner = insert(:user)
    other_owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)
    {:ok, other} = Accounts.create_account(%{name: "Other"}, other_owner)
    agent = insert(:user)
    {:ok, _} = Accounts.add_member(account, agent)
    %{account: account, other: other, owner: owner, other_owner: other_owner, agent: agent}
  end

  test "creates teams with upstream defaults, scoped listing and unique names per account", %{
    account: account,
    other: other
  } do
    assert {:ok, %Team{allow_auto_assign: true, icon: "", icon_color: ""} = team} =
             Accounts.create_team(account, %{name: "Support", description: "First line"})

    assert {:error, changeset} = Accounts.create_team(account, %{name: "Support"})
    assert %{name: [_]} = errors_on(changeset)
    assert {:ok, _} = Accounts.create_team(other, %{name: "Support"})
    assert [%Team{id: id}] = Accounts.list_teams(account)
    assert id == team.id
    assert_raise Ecto.NoResultsError, fn -> Accounts.get_team!(other, team.id) end
  end

  test "only members of the same account can join a team, once", %{
    account: account,
    other: other,
    owner: owner,
    other_owner: outsider,
    agent: agent
  } do
    {:ok, team} = Accounts.create_team(account, %{name: "Support"})
    {:ok, other_team} = Accounts.create_team(other, %{name: "Other"})

    assert {:ok, %TeamMember{team_id: team_id, user_id: user_id}} =
             Accounts.add_team_member(account, team.id, agent.id)

    assert {team_id, user_id} == {team.id, agent.id}
    assert {:error, :not_found} = Accounts.add_team_member(account, team.id, outsider.id)
    assert {:error, :not_found} = Accounts.add_team_member(account, other_team.id, owner.id)
    assert {:error, changeset} = Accounts.add_team_member(account, team.id, agent.id)
    assert %{team_id: [_]} = errors_on(changeset)
    assert [%TeamMember{user_id: id}] = Accounts.list_team_members(account, team.id)
    assert id == agent.id
    assert_raise Ecto.NoResultsError, fn -> Accounts.list_team_members(other, team.id) end
  end

  test "inbox membership requires both inbox and agent to belong to the account", %{
    account: account,
    other: other,
    owner: owner,
    other_owner: outsider,
    agent: agent
  } do
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Telegram", channel_type: "telegram"})

    {:ok, other_inbox} =
      Inboxes.create_inbox(other, %{name: "Telegram", channel_type: "telegram"})

    assert {:ok, %InboxMember{inbox_id: inbox_id, user_id: user_id}} =
             Inboxes.add_member(account, inbox.id, agent.id)

    assert {inbox_id, user_id} == {inbox.id, agent.id}
    assert {:error, :not_found} = Inboxes.add_member(account, inbox.id, outsider.id)
    assert {:error, :not_found} = Inboxes.add_member(account, other_inbox.id, owner.id)
    assert {:error, changeset} = Inboxes.add_member(account, inbox.id, agent.id)
    assert %{inbox_id: [_]} = errors_on(changeset)
    assert [%InboxMember{user_id: id}] = Inboxes.list_members(account, inbox.id)
    assert id == agent.id
    assert_raise Ecto.NoResultsError, fn -> Inboxes.list_members(other, inbox.id) end
  end

  test "physical PostgreSQL catalog contains the new tables and upstream indexes" do
    report = SchemaParity.compare(Repo, @schema)

    for name <- ~w(teams team_members inbox_members) do
      assert report.tables[name].status == :present
      assert report.tables[name].missing_columns == []

      assert Enum.all?(report.tables[name].indexes, fn {_name, diff} ->
               diff.status != :missing
             end)
    end

    for name <- ~w(teams team_members) do
      assert report.tables[name].columns["created_at"].status == :equal
      assert report.tables[name].columns["updated_at"].status == :equal
    end

    assert report.tables["inbox_members"].columns["created_at"].status == :equal
    assert report.tables["inbox_members"].columns["updated_at"].status == :equal
    assert report.tables["inbox_members"].primary_key.actual.type == "integer"
    assert report.tables["teams"].columns["account_id"].actual.type == "bigint"
    assert report.tables["inbox_members"].columns["user_id"].status == :different
  end
end
