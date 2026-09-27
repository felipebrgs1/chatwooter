defmodule Chatwooter.CoreConversationRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.CoreConversationParityFixture

  test "upstream enums, polymorphic sender, JSON values and microseconds load intact" do
    CoreConversationParityFixture.insert!(Repo)

    for {schema, attrs, defaults} <- CoreConversationParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "integer enums use the exact Rails values" do
    CoreConversationParityFixture.insert!(Repo)
    assert [[3]] = Repo.query!("SELECT status FROM conversations WHERE id = 120001").rows

    assert [[3, 9, 2]] =
             Repo.query!(
               "SELECT message_type, content_type, status FROM messages WHERE id = 120002"
             ).rows

    assert [[8]] = Repo.query!("SELECT file_type FROM attachments WHERE id = 120003").rows
  end

  test "attachment mapping reads restored external URLs without local storage records" do
    CoreConversationParityFixture.insert!(Repo)
    message = Repo.get!(Chatwooter.Conversations.Message, 120_002)

    assert [%{url: "https://example.test/restored", key: nil}] =
             Chatwooter.Conversations.list_attachments(message)
  end
end
