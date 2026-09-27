defmodule Chatwooter.WidgetSessionRestoredDataTest do
  use Chatwooter.DataCase, async: true
  alias Chatwooter.Accounts.UserSession
  alias Chatwooter.WidgetSessionParityFixture

  test "preserves widget fields and session metadata and timestamp precision" do
    WidgetSessionParityFixture.insert!(Repo)

    for {schema, attrs, defaults} <- WidgetSessionParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "redacts session client and widget authentication identifiers" do
    WidgetSessionParityFixture.insert!(Repo)

    for {schema, attrs, _defaults} <- WidgetSessionParityFixture.rows(),
        field <- [:website_token, :hmac_token, :client_id],
        Map.has_key?(attrs, field) do
      refute inspect(Repo.get!(schema, attrs.id)) =~ Map.fetch!(attrs, field)
    end
  end

  test "sessions require a real user reference" do
    assert {:error, %Postgrex.Error{postgres: %{code: :foreign_key_violation}}} =
             Repo.query(
               "INSERT INTO user_sessions (user_id, client_id, created_at, updated_at) VALUES (999999999, 'missing-user', now(), now())"
             )
  end

  test "nullable user metadata remains nil" do
    WidgetSessionParityFixture.insert!(Repo)

    Repo.query!(
      "INSERT INTO user_sessions (id, user_id, client_id, created_at, updated_at) VALUES (95003, 7002, 'other-client', now(), now())"
    )

    assert %{last_activity_at: nil, ip_address: nil, user_agent: nil} =
             Repo.get!(UserSession, 95_003)
  end
end
