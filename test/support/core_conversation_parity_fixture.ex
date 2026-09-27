defmodule Chatwooter.CoreConversationParityFixture do
  @moduledoc false
  @created ~U[2026-09-24 10:30:00.123456Z]

  def rows do
    [
      {Chatwooter.Conversations.Conversation,
       %{
         id: 120_001,
         account_id: 7001,
         inbox_id: 7003,
         display_id: 1,
         status: :snoozed,
         contact_id: 7002,
         contact_inbox_id: nil,
         uuid: "a44c13a1-22c7-4440-8bdd-7e5d7a105277",
         last_activity_at: @created,
         waiting_since: @created,
         status_changed_at: @created,
         additional_attributes: [%{"source" => "dump"}],
         inserted_at: @created,
         updated_at: @created
       }, %{custom_attributes: %{}}},
      {Chatwooter.Conversations.Message,
       %{
         id: 120_002,
         account_id: 7001,
         inbox_id: 7003,
         conversation_id: 120_001,
         message_type: :template,
         upstream_content_type: :input_csat,
         status: :read,
         sender_type: "Contact",
         sender_id: 7002,
         source_id: String.duplicate("x", 300),
         content: "Restored upstream",
         content_attributes: [%{"value" => 5}],
         inserted_at: @created,
         updated_at: @created
       },
       %{private: false, external_source_ids: %{}, additional_attributes: %{}, sentiment: %{}}},
      {Chatwooter.Conversations.Attachment,
       %{
         id: 120_003,
         account_id: 7001,
         message_id: 120_002,
         file_type: :contact,
         external_url: "https://example.test/restored",
         coordinates_lat: 10.5,
         coordinates_long: -40.25,
         meta: [%{"name" => "Restored"}],
         inserted_at: @created,
         updated_at: @created
       }, %{}}
    ]
  end

  def insert!(repo) do
    for {schema, attrs, _defaults} <- rows() do
      fields = Map.keys(attrs) |> Enum.sort()
      columns = Enum.map_join(fields, ", ", &Atom.to_string(schema.__schema__(:field_source, &1)))
      placeholders = 1..length(fields) |> Enum.map_join(", ", &"$#{&1}")

      values =
        Enum.map(fields, fn field ->
          type = schema.__schema__(:type, field)
          {:ok, dumped} = Ecto.Type.dump(type, Map.fetch!(attrs, field))
          dumped
        end)

      repo.query!(
        "INSERT INTO #{schema.__schema__(:source)} (#{columns}) VALUES (#{placeholders})",
        values
      )
    end

    :ok
  end
end
