defmodule Chatwooter.HelpCenterRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.HelpCenterParityFixture
  alias Chatwooter.Platform.Portal
  alias Chatwooter.Platform.PortalMember

  test "all help center rows and database defaults load without changing source values" do
    HelpCenterParityFixture.insert!(Repo)

    for {schema, attrs, defaults} <- HelpCenterParityFixture.rows() do
      record =
        Repo.get_by!(
          schema,
          Map.take(attrs, schema.__schema__(:primary_key) ++ [:portal_id, :user_id])
        )

      for {field, value} <- Map.merge(defaults, attrs) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "portal membership has no synthetic primary key" do
    assert PortalMember.__schema__(:primary_key) == []
    refute :id in PortalMember.__schema__(:fields)
  end

  test "SSL settings retain their stored data while inspection redacts credentials" do
    HelpCenterParityFixture.insert!(Repo)
    record = Repo.get!(Portal, 93_001)
    assert record.ssl_settings == %{}
    record = %{record | ssl_settings: %{"private_key" => "private-fixture-key"}}
    refute inspect(record) =~ "private-fixture-key"
  end

  test "inbox portal reference matches upstream nullable NO ACTION relationship" do
    assert [[true, "bigint", "a"]] =
             Repo.query!("""
             SELECT NOT a.attnotnull, format_type(a.atttypid, a.atttypmod), c.confdeltype::text
             FROM pg_attribute a
             JOIN pg_constraint c ON c.conrelid = a.attrelid AND a.attnum = ANY(c.conkey)
             WHERE a.attrelid = 'inboxes'::regclass AND a.attname = 'portal_id' AND c.contype = 'f'
             """).rows
  end
end
