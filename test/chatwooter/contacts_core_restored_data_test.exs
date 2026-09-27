defmodule Chatwooter.ContactsCoreRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.Companies.Company
  alias Chatwooter.Contacts.Contact
  alias Chatwooter.Contacts.ContactInbox
  alias Chatwooter.ContactsCoreParityFixture

  test "all restored fields remain readable through the existing operational schemas" do
    ContactsCoreParityFixture.insert!(Repo)

    for {schema, attrs, defaults} <- ContactsCoreParityFixture.rows() do
      record = Repo.get!(schema, attrs.id)

      for {field, value} <- Map.merge(defaults, attrs) do
        assert Map.fetch!(record, field) == value, "#{inspect(schema)}.#{field}"
      end
    end
  end

  test "restored nullable CRM rows preserve their source fields and timestamp precision" do
    created = ~N[2026-09-24 10:30:00.123456]

    Repo.query!(
      """
      INSERT INTO contacts (id, account_id, created_at, updated_at, name, additional_attributes, custom_attributes,
      identifier, last_activity_at, contact_type, middle_name, last_name, location, country_code, blocked)
      VALUES (94001, 7001, $1, $1, NULL, NULL, '{"vip":true}', 'restored-contact', $1, 1, 'Middle', 'Last', 'City', 'BR', true)
      """,
      [created]
    )

    record = Repo.get!(Contact, 94_001)
    assert record.name == nil
    assert record.additional_attributes == nil
    assert record.custom_attributes == %{"vip" => true}
    assert record.identifier == "restored-contact"
    assert record.contact_type == 1
    assert record.middle_name == "Middle"
    assert record.last_name == "Last"
    assert record.location == "City"
    assert record.country_code == "BR"
    assert record.blocked
    assert record.inserted_at == DateTime.from_naive!(created, "Etc/UTC")
    assert record.updated_at == record.inserted_at
    assert record.last_activity_at == record.inserted_at

    Repo.query!(
      """
      INSERT INTO contact_inboxes (id, source_id, created_at, updated_at, pubsub_token)
      VALUES (94002, $1, $2, $2, 'synthetic-pubsub-token')
      """,
      [String.duplicate("x", 400), created]
    )

    identity = Repo.get!(ContactInbox, 94_002)
    assert identity.contact_id == nil
    assert identity.inbox_id == nil
    assert identity.source_id == String.duplicate("x", 400)
    assert identity.hmac_verified == false
    assert identity.pubsub_token == "synthetic-pubsub-token"
    assert identity.inserted_at == record.inserted_at
    refute inspect(identity) =~ "synthetic-pubsub-token"

    Repo.query!(
      """
      INSERT INTO companies (id, name, account_id, created_at, updated_at, contacts_count, last_activity_at)
      VALUES (94003, 'Imported company', 7001, $1, $1, 17, $1)
      """,
      [created]
    )

    company = Repo.get!(Company, 94_003)
    assert company.contacts_count == 17
    assert company.additional_attributes == %{}
    assert company.custom_attributes == %{}
    assert company.inserted_at == record.inserted_at
    assert company.last_activity_at == record.inserted_at
  end

  test "source permits duplicate phone numbers and several identities for the same contact and inbox" do
    Repo.query!("""
    INSERT INTO contacts (account_id, phone_number, created_at, updated_at)
    VALUES (7001, '+5511999', now(), now()), (7001, '+5511999', now(), now())
    """)

    Repo.query!("""
    INSERT INTO contact_inboxes (contact_id, inbox_id, source_id, created_at, updated_at)
    VALUES (7002, 7003, 'identity-a', now(), now()), (7002, 7003, 'identity-b', now(), now())
    """)

    assert Repo.aggregate(from(c in Contact, where: c.phone_number == "+5511999"), :count) == 2
  end
end
