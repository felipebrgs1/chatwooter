defmodule Chatwooter.CampaignParityFixture do
  @moduledoc false
  @created ~N[2026-09-24 10:30:00.123456]

  def rows do
    [
      {Chatwooter.Automations.Campaign,
       %{
         id: 130_001,
         display_id: 7,
         title: "Fixture campaign",
         description: "Restored description",
         message: "Restored message",
         sender_id: 7302,
         account_id: 7301,
         inbox_id: 7303,
         trigger_rules: %{"trigger" => "rule"},
         campaign_type: 1,
         campaign_status: 2,
         audience: [%{"type" => "contact"}],
         scheduled_at: ~N[2026-09-25 09:00:00],
         template_params: %{"param" => "value"},
         started_at: @created,
         completed_at: @created,
         created_at: @created,
         updated_at: @created
       },
       %{
         enabled: true,
         trigger_only_during_business_hours: false
       }},
      {Chatwooter.Automations.CampaignRecipient,
       %{
         id: 130_002,
         account_id: 7301,
         campaign_id: 130_001,
         contact_id: 7304,
         inbox_id: 7303,
         source_id: "campaign-fixture-source",
         status: 3,
         error_code: "E1",
         error_title: "Failed",
         error_message: "Restored error",
         message_content: "Restored content",
         sent_at: @created,
         delivered_at: @created,
         read_at: @created,
         failed_at: @created,
         created_at: @created,
         updated_at: @created
       }, %{}}
    ]
  end

  def insert!(repo) do
    repo.query!(
      "INSERT INTO accounts (id, name, created_at, updated_at) VALUES (7301, 'Campaign fixture', $1, $1) ON CONFLICT (id) DO NOTHING",
      [~N[2026-09-24 10:30:00]]
    )

    repo.query!(
      "INSERT INTO inboxes (id, channel_id, account_id, name, created_at, updated_at) VALUES (7303, 1, 7301, 'Campaign fixture', $1, $1) ON CONFLICT (id) DO NOTHING",
      [~N[2026-09-24 10:30:00]]
    )

    repo.query!(
      "INSERT INTO contacts (id, account_id, created_at, updated_at) VALUES (7304, 7301, $1, $1) ON CONFLICT (id) DO NOTHING",
      [~N[2026-09-24 10:30:00]]
    )

    for {schema, attrs, _defaults} <- rows() do
      columns = Map.keys(attrs) |> Enum.sort()
      keys = Enum.map_join(columns, ", ", &Atom.to_string/1)
      placeholders = 1..length(columns) |> Enum.map_join(", ", &"$#{&1}")
      values = Enum.map(columns, &Map.fetch!(attrs, &1))
      table = schema.__schema__(:source)
      repo.query!("INSERT INTO #{table} (#{keys}) VALUES (#{placeholders})", values)
    end

    :ok
  end
end
