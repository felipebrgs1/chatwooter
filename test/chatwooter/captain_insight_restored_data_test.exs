defmodule Chatwooter.CaptainInsightRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.CaptainInsightParityFixture

  test "restored captain insight rows retain IDs, enums, JSON and vectors" do
    CaptainInsightParityFixture.insert!(Repo)

    for {schema, attrs, defaults} <- CaptainInsightParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) |> Map.delete(:embedding) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "restored FAQ embeddings keep 1536 dimensions" do
    CaptainInsightParityFixture.insert!(Repo)

    assert {:ok, %{rows: [[text]]}} =
             Repo.query("SELECT embedding::text FROM captain_faq_suggestions WHERE id = 132001")

    assert text == CaptainInsightParityFixture.embedding_text()
  end

  test "omitted insight languages, statuses and counters retain upstream defaults" do
    CaptainInsightParityFixture.insert!(Repo)
    created = ~N[2026-09-24 10:30:00.123456]

    Repo.query!(
      "INSERT INTO captain_faq_suggestions (id, question, answer, assistant_id, account_id, created_at, updated_at) VALUES (132011, 'Q', 'A', 131001, 7301, $1, $1)",
      [created]
    )

    assert %{language: "en", source_count: 0, status: 0} =
             Repo.get!(Chatwooter.Captain.FaqSuggestion, 132_011)

    Repo.query!(
      "INSERT INTO conversation_outcomes (id, account_id, assistant_id, conversation_id, inbox_id, started_at, created_at, updated_at) VALUES (132012, 7301, 131001, 133010, 7303, $1, $1, $1)",
      [~N[2026-09-25 10:30:00.123456]]
    )

    assert %{captain_reply_count: 0, episode_trigger: "initial"} =
             Repo.get!(Chatwooter.Conversations.Outcome, 132_012)
  end

  test "observation keeps one row per conversation and suggestion" do
    CaptainInsightParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO captain_faq_observations (account_id, conversation_id, faq_suggestion_id, generated_question, generated_answer, created_at, updated_at) VALUES (7301, 133010, 132001, 'Q', 'A', now(), now())"
             )
  end
end
