defmodule Chatwooter.CaptainAssistantRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.CaptainAssistantParityFixture

  test "restored captain assistant rows retain IDs, JSON, vectors and defaults" do
    CaptainAssistantParityFixture.insert!(Repo)

    for {schema, attrs, defaults} <- CaptainAssistantParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) |> Map.delete(:embedding) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "restored embeddings keep 1536 dimensions" do
    CaptainAssistantParityFixture.insert!(Repo)

    assert {:ok, %{rows: [[text]]}} =
             Repo.query(
               "SELECT embedding::text FROM captain_assistant_responses WHERE id = 131006"
             )

    assert text == CaptainAssistantParityFixture.embedding_text()
  end

  test "omitted assistant config and tool fields retain upstream defaults" do
    CaptainAssistantParityFixture.insert!(Repo)
    created = ~N[2026-09-24 10:30:00.123456]

    Repo.query!(
      "INSERT INTO captain_assistants (id, name, account_id, created_at, updated_at) VALUES (131011, 'Defaults', 7301, $1, $1)",
      [created]
    )

    assert %{config: %{}, response_guidelines: [], guardrails: []} =
             Repo.get!(Chatwooter.Captain.Assistant, 131_011)

    Repo.query!(
      "INSERT INTO captain_custom_tools (id, account_id, slug, title, endpoint_url, created_at, updated_at) VALUES (131012, 7301, 'defaults-tool', 'Defaults', 'https://example.test/d', $1, $1)",
      [created]
    )

    assert %{
             http_method: "GET",
             auth_type: "none",
             auth_config: %{},
             param_schema: [],
             enabled: true
           } = Repo.get!(Chatwooter.Captain.CustomTool, 131_012)
  end

  test "assistant tool slug is unique per assistant" do
    CaptainAssistantParityFixture.insert!(Repo)

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO captain_custom_tools (account_id, slug, title, endpoint_url, assistant_id, created_at, updated_at) VALUES (7301, 'fixture-tool', 'Dup', 'https://example.test/d', 131001, now(), now())"
             )
  end

  test "custom tool auth config is redacted from struct inspection" do
    CaptainAssistantParityFixture.insert!(Repo)

    record = Repo.get!(Chatwooter.Captain.CustomTool, 131_005)
    refute inspect(record) =~ "synthetic-tool-token"
  end
end
