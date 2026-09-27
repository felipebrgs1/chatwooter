defmodule Chatwooter.CapacityRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.CapacityParityFixture

  test "all seven restored rows retain IDs, JSON, dates, enum integers and precision" do
    CapacityParityFixture.insert!(Repo)
    assert length(CapacityParityFixture.rows()) == 7

    for {schema, attrs, defaults} <- CapacityParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "nullable SAML fields and JSON default survive raw restoration" do
    created = ~N[2026-09-24 10:30:00.123456]

    Repo.query!(
      "INSERT INTO account_saml_settings (id, account_id, created_at, updated_at) VALUES (82001, 7001, $1, $1)",
      [created]
    )

    assert %{
             role_mappings: %{},
             certificate: nil,
             sso_url: nil,
             sp_entity_id: nil,
             idp_entity_id: nil
           } =
             Repo.get!(Chatwooter.Accounts.AccountSamlSetting, 82_001)
  end

  test "stored Rails enum integers are not converted or constrained" do
    created = ~N[2026-09-24 10:30:00.123456]

    Repo.query!(
      "INSERT INTO leaves (id, account_id, user_id, start_date, end_date, leave_type, status, created_at, updated_at) VALUES (82002, 7001, 7002, $1, $1, 3, 2, $2, $2)",
      [~D[2026-09-24], created]
    )

    assert %{leave_type: 3, status: 2, approved_at: nil, approved_by_id: nil, reason: nil} =
             Repo.get!(Chatwooter.Accounts.Leave, 82_002)
  end

  test "SAML certificate is excluded from struct inspection" do
    CapacityParityFixture.insert!(Repo)
    saml = Repo.get!(Chatwooter.Accounts.AccountSamlSetting, 72_001)
    refute inspect(saml) =~ saml.certificate
  end

  test "an inbox can reference only one assignment policy" do
    CapacityParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO inbox_assignment_policies (inbox_id, assignment_policy_id, created_at, updated_at) VALUES (7003, 72003, now(), now())"
             )
  end

  test "a capacity limit is unique within policy and inbox" do
    CapacityParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO inbox_capacity_limits (agent_capacity_policy_id, inbox_id, conversation_limit, created_at, updated_at) VALUES (72002, 7003, 5, now(), now())"
             )
  end

  test "assignment policy names are unique per account" do
    CapacityParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO assignment_policies (account_id, name, created_at, updated_at) VALUES (7001, 'Round robin', now(), now())"
             )
  end
end
