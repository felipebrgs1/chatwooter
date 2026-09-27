defmodule Chatwooter.CapacityParityFixture do
  @moduledoc false
  @created ~N[2026-09-24 10:30:00.123456]

  def rows do
    [
      {Chatwooter.Accounts.AccountSamlSetting,
       %{
         id: 72_001,
         account_id: 7001,
         sso_url: "https://example.test/sso",
         certificate: "synthetic-saml-certificate",
         sp_entity_id: String.duplicate("s", 300),
         idp_entity_id: "fixture-idp",
         role_mappings: [%{"role" => "administrator", "groups" => ["admin"]}],
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Accounts.AgentCapacityPolicy,
       %{
         id: 72_002,
         account_id: 7001,
         name: "Capacity",
         description: "Synthetic capacity",
         created_at: @created,
         updated_at: @created
       }, %{exclusion_rules: %{}}},
      {Chatwooter.Accounts.AssignmentPolicy,
       %{
         id: 72_003,
         account_id: 7001,
         name: "Round robin",
         description: "Synthetic assignment",
         created_at: @created,
         updated_at: @created
       },
       %{
         assignment_order: 0,
         conversation_priority: 0,
         fair_distribution_limit: 100,
         fair_distribution_window: 3600,
         enabled: true,
         exclude_older_than_hours: 168
       }},
      {Chatwooter.Inboxes.InboxAssignmentPolicy,
       %{
         id: 72_004,
         inbox_id: 7003,
         assignment_policy_id: 72_003,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Inboxes.InboxCapacityLimit,
       %{
         id: 72_005,
         inbox_id: 7003,
         agent_capacity_policy_id: 72_002,
         conversation_limit: 12,
         created_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Accounts.Leave,
       %{
         id: 72_006,
         account_id: 7001,
         user_id: 7002,
         start_date: ~D[2026-09-24],
         end_date: ~D[2026-09-27],
         reason: "Synthetic absence",
         approved_by_id: 7008,
         approved_at: @created,
         created_at: @created,
         updated_at: @created
       }, %{leave_type: 0, status: 0}},
      {Chatwooter.Contacts.Folder,
       %{
         id: 72_007,
         account_id: 7001,
         category_id: 7009,
         name: String.duplicate("f", 300),
         created_at: @created,
         updated_at: @created
       }, %{}}
    ]
  end

  def insert!(repo) do
    for {schema, attrs, _defaults} <- rows() do
      columns = Map.keys(attrs) |> Enum.sort()
      keys = Enum.map_join(columns, ", ", &Atom.to_string/1)
      placeholders = 1..length(columns) |> Enum.map_join(", ", &"$#{&1}")
      values = Enum.map(columns, &Map.fetch!(attrs, &1))
      table = schema.__schema__(:source)
      repo.query!("INSERT INTO #{table} (#{keys}) VALUES (#{placeholders})", values)
    end

    :ok
  end
end
