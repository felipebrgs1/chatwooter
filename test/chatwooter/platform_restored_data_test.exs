defmodule Chatwooter.PlatformRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.PlatformParityFixture

  test "loads all twenty upstream rows without changing IDs or stored field values" do
    PlatformParityFixture.insert!(Repo)

    for {schema, attrs, defaults} <- PlatformParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "nullable fields and JSONB/SQL-array defaults are preserved" do
    created = ~N[2026-09-24 10:30:00.123456]

    Repo.query!(
      "INSERT INTO custom_roles (id, account_id, created_at, updated_at) VALUES (80001, 7001, $1, $1)",
      [created]
    )

    assert %{permissions: [], name: nil, description: nil} =
             Repo.get!(Chatwooter.Accounts.CustomRole, 80_001)

    Repo.query!(
      "INSERT INTO dashboard_apps (id, title, account_id, created_at, updated_at) VALUES (80001, 'Fixture', 7001, $1, $1)",
      [created]
    )

    assert %{content: [], user_id: nil} = Repo.get!(Chatwooter.Platform.DashboardApp, 80_001)

    Repo.query!(
      "INSERT INTO custom_filters (id, name, user_id, account_id, created_at, updated_at) VALUES (80001, 'Fixture', 7002, 7001, $1, $1)",
      [created]
    )

    assert %{query: %{}, filter_type: 0} = Repo.get!(Chatwooter.Accounts.CustomFilter, 80_001)
  end

  test "CSAT has one response per message" do
    PlatformParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO csat_survey_responses (account_id, conversation_id, message_id, contact_id, rating, created_at, updated_at) VALUES (7001, 7004, 7005, 7006, 4, now(), now())"
             )
  end

  test "tokens and secrets are excluded from default struct inspection" do
    PlatformParityFixture.insert!(Repo)

    for {schema, attrs, _defaults} <- PlatformParityFixture.rows(),
        field <- [:token, :secret, :access_token],
        Map.has_key?(attrs, field) do
      refute inspect(Repo.get!(schema, attrs.id)) =~ Map.fetch!(attrs, field)
    end
  end
end
