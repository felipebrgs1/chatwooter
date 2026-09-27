defmodule Chatwooter.WaTgRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.WaTgParityFixture

  test "reads preserved provider data without activating adapters or hooks" do
    WaTgParityFixture.insert!(Repo)

    for {schema, attrs, defaults} <- WaTgParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "provider secrets are redacted from struct inspection" do
    WaTgParityFixture.insert!(Repo)

    for {schema, attrs, _defaults} <- WaTgParityFixture.rows(),
        field <- [:bot_token, :business_management_token],
        Map.has_key?(attrs, field) do
      refute inspect(Repo.get!(schema, attrs.id)) =~ Map.fetch!(attrs, field)
    end
  end

  test "WhatsApp defaults remain intact for restored rows with nullable provider data" do
    Repo.query!(
      "INSERT INTO channel_whatsapp (id, account_id, phone_number, created_at, updated_at) VALUES (94003, 7001, '+5585999990002', now(), now())"
    )

    assert %{
             provider: "default",
             provider_config: %{},
             message_templates: %{},
             phone_number_health: %{},
             business_management_token: nil
           } = Repo.get!(Chatwooter.Channels.WhatsAppRecord, 94_003)
  end

  test "Telegram bot identity is unique across accounts" do
    WaTgParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO channel_telegram (account_id, bot_token, created_at, updated_at) VALUES (7002, 'synthetic-bot-token', now(), now())"
             )
  end
end
