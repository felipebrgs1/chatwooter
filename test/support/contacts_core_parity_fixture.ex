defmodule Chatwooter.ContactsCoreParityFixture do
  @moduledoc false
  @created ~U[2026-09-24 10:30:00.123456Z]

  def rows do
    [
      {Chatwooter.Companies.Company,
       %{
         id: 95_001,
         account_id: 7001,
         name: "Restored company",
         domain: "fixture.example.test",
         description: "Imported description",
         additional_attributes: %{"industry" => "tech"},
         custom_attributes: %{"vip" => true},
         contacts_count: 17,
         last_activity_at: @created,
         inserted_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Contacts.Contact,
       %{
         id: 95_002,
         account_id: 7001,
         company_id: 95_001,
         name: "Imported contact",
         email: "restored@example.test",
         phone_number: "+551199999",
         identifier: "restored-identity",
         additional_attributes: %{"company_name" => "Restored company"},
         custom_attributes: %{"vip" => true},
         last_activity_at: @created,
         contact_type: 1,
         middle_name: "Middle",
         last_name: "Last",
         location: "Fortaleza",
         country_code: "BR",
         blocked: true,
         inserted_at: @created,
         updated_at: @created
       }, %{}},
      {Chatwooter.Contacts.ContactInbox,
       %{
         id: 95_003,
         contact_id: 95_002,
         inbox_id: 7003,
         source_id: "restored-source",
         pubsub_token: "synthetic-pubsub-token",
         inserted_at: @created,
         updated_at: @created
       }, %{hmac_verified: false}}
    ]
  end

  def insert!(repo) do
    for {schema, attrs, _defaults} <- rows() do
      fields = Map.keys(attrs) |> Enum.sort()
      keys = Enum.map_join(fields, ", ", &Atom.to_string(schema.__schema__(:field_source, &1)))
      placeholders = 1..length(fields) |> Enum.map_join(", ", &"$#{&1}")
      values = Enum.map(fields, &database_value(Map.fetch!(attrs, &1)))
      table = schema.__schema__(:source)
      repo.query!("INSERT INTO #{table} (#{keys}) VALUES (#{placeholders})", values)
    end

    :ok
  end

  defp database_value(%DateTime{} = value), do: DateTime.to_naive(value)
  defp database_value(value), do: value
end
