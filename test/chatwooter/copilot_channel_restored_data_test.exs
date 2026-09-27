defmodule Chatwooter.CopilotChannelRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.CopilotChannelParityFixture

  test "restored copilot, embedding and channel rows retain IDs and defaults" do
    CopilotChannelParityFixture.insert!(Repo)

    for {schema, attrs, defaults} <- CopilotChannelParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) |> Map.delete(:embedding) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "restored article embeddings keep 1536 dimensions" do
    CopilotChannelParityFixture.insert!(Repo)

    assert {:ok, %{rows: [[text]]}} =
             Repo.query("SELECT embedding::text FROM article_embeddings WHERE id = 134003")

    assert text == CopilotChannelParityFixture.embedding_text()
  end

  test "omitted copilot message and twitter flags retain upstream defaults" do
    CopilotChannelParityFixture.insert!(Repo)
    created = ~N[2026-09-24 10:30:00.123456]

    Repo.query!(
      "INSERT INTO copilot_messages (id, copilot_thread_id, account_id, created_at, updated_at) VALUES (134011, 134001, 7301, $1, $1)",
      [created]
    )

    assert %{message: %{}, message_type: 0} =
             Repo.get!(Chatwooter.Platform.CopilotMessage, 134_011)

    Repo.query!(
      "INSERT INTO channel_twitter_profiles (id, profile_id, twitter_access_token, twitter_access_token_secret, account_id, created_at, updated_at) VALUES (134012, 'defaults-profile', 'x', 'y', 7301, $1, $1)",
      [created]
    )

    assert %{tweets_enabled: true} =
             Repo.get!(Chatwooter.Channels.TwitterProfileRecord, 134_012)
  end

  test "all restored channel credentials are redacted from struct inspection" do
    CopilotChannelParityFixture.insert!(Repo)

    tiktok = Repo.get!(Chatwooter.Channels.TiktokRecord, 134_004)
    refute inspect(tiktok) =~ "synthetic-tiktok-token"
    refute inspect(tiktok) =~ "synthetic-tiktok-refresh"

    twilio = Repo.get!(Chatwooter.Channels.TwilioSmsRecord, 134_005)
    refute inspect(twilio) =~ "synthetic-twilio-auth"
    refute inspect(twilio) =~ "synthetic-twilio-secret"
    refute inspect(twilio) =~ "synthetic-twilio-config"

    twitter = Repo.get!(Chatwooter.Channels.TwitterProfileRecord, 134_006)
    refute inspect(twitter) =~ "synthetic-twitter-token"
    refute inspect(twitter) =~ "synthetic-twitter-secret"
  end

  test "tiktok business identity stays unique" do
    CopilotChannelParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO channel_tiktok (account_id, business_id, access_token, expires_at, refresh_token, refresh_token_expires_at, created_at, updated_at) VALUES (7301, 'fixture-business', 'x', now(), 'y', now(), now(), now())"
             )
  end
end
