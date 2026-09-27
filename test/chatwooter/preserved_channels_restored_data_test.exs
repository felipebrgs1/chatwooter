defmodule Chatwooter.PreservedChannelsRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.PreservedChannelsParityFixture

  test "restored inactive channels retain IDs, provider data and database defaults" do
    PreservedChannelsParityFixture.insert!(Repo)

    for {schema, attrs, defaults} <- PreservedChannelsParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "all restored credentials are redacted from struct inspection" do
    PreservedChannelsParityFixture.insert!(Repo)

    for {schema, attrs, _defaults} <- PreservedChannelsParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for field <- [
            :hmac_token,
            :secret,
            :imap_password,
            :smtp_password,
            :user_access_token,
            :page_access_token,
            :access_token,
            :line_channel_secret,
            :line_channel_token,
            :provider_config
          ],
          Map.has_key?(attrs, field) do
        value = Map.fetch!(attrs, field)
        secret = if is_map(value), do: value["token"], else: value
        refute inspect(record) =~ secret
      end
    end
  end

  test "omitted mail credentials and JSON config retain upstream defaults" do
    created = ~N[2026-09-24 10:30:00.123456]

    Repo.query!(
      "INSERT INTO channel_email (id, account_id, email, forward_to_email, created_at, updated_at) VALUES (102001, 7001, 'defaults@example.test', 'defaults-forward@example.test', $1, $1)",
      [created]
    )

    assert %{imap_password: "", smtp_password: "", provider_config: %{}, provider: nil} =
             Repo.get!(Chatwooter.Channels.EmailRecord, 102_001)

    Repo.query!(
      "INSERT INTO channel_sms (id, account_id, phone_number, created_at, updated_at) VALUES (102002, 7001, '+5511888888888', $1, $1)",
      [created]
    )

    assert %{provider: "default", provider_config: %{}} =
             Repo.get!(Chatwooter.Channels.SmsRecord, 102_002)
  end

  test "restored API attributes preserve JSON arrays and nullable secrets" do
    created = ~N[2026-09-24 10:30:00.123456]

    Repo.query!(
      "INSERT INTO channel_api (id, account_id, additional_attributes, created_at, updated_at) VALUES (102003, 7001, $1, $2, $2)",
      [[%{"key" => "value"}], created]
    )

    assert %{
             additional_attributes: [%{"key" => "value"}],
             secret: nil,
             hmac_token: nil,
             identifier: nil,
             webhook_url: nil
           } =
             Repo.get!(Chatwooter.Channels.ApiRecord, 102_003)
  end

  test "Facebook page identity is unique within an account" do
    PreservedChannelsParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO channel_facebook_pages (page_id, user_access_token, page_access_token, account_id, created_at, updated_at) VALUES ('page-fixture', 'x', 'y', 7001, now(), now())"
             )
  end

  test "email identity and forwarding destination each remain unique" do
    PreservedChannelsParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO channel_email (email, forward_to_email, account_id, created_at, updated_at) VALUES ('fixture@example.test', 'other@example.test', 7001, now(), now())"
             )
  end
end
