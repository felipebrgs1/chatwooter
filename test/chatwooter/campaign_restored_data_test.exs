defmodule Chatwooter.CampaignRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.CampaignParityFixture

  test "restored campaigns retain IDs, enums, JSON and timestamps" do
    CampaignParityFixture.insert!(Repo)

    for {schema, attrs, defaults} <- CampaignParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "omitted campaign flags and JSON retain upstream defaults" do
    CampaignParityFixture.insert!(Repo)

    Repo.query!(
      "INSERT INTO campaigns (id, display_id, title, message, account_id, inbox_id, created_at, updated_at) VALUES (130011, 8, 'Defaults', 'Hi', 7301, 7303, now(), now())"
    )

    assert %{
             enabled: true,
             trigger_rules: %{},
             campaign_type: 0,
             campaign_status: 0,
             audience: [],
             trigger_only_during_business_hours: false
           } = Repo.get!(Chatwooter.Automations.Campaign, 130_011)
  end

  test "campaign recipient keeps the contact unique per campaign" do
    CampaignParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO campaign_recipients (account_id, campaign_id, contact_id, inbox_id, created_at, updated_at) VALUES (7301, 130001, 7304, 7303, now(), now())"
             )
  end

  test "campaign display_id is assigned from the per-account sequence" do
    CampaignParityFixture.insert!(Repo)

    Repo.query!(
      "INSERT INTO campaigns (title, message, account_id, inbox_id, created_at, updated_at) VALUES ('Sequenced', 'Hi', 7301, 7303, now(), now())"
    )

    assert %{display_id: display_id} =
             Repo.one!(Chatwooter.Automations.Campaign |> Ecto.Query.where(title: "Sequenced"))

    assert is_integer(display_id)
  end
end
