defmodule Chatwooter.CrmRestoredDataTest do
  use Chatwooter.DataCase, async: true

  alias Chatwooter.Accounts.Account
  alias Chatwooter.{Contacts, Conversations, Inboxes}

  @created ~N[2026-09-24 10:30:00.123456]

  test "reads preserved CRM IDs, enums, JSON arrays and timestamps with account isolation" do
    for account_id <- [7001, 7002] do
      Repo.query!(
        "INSERT INTO labels (id, title, account_id, created_at, updated_at) VALUES ($1, $2, $3, $4, $4)",
        [account_id, String.duplicate("a", 300), account_id, @created]
      )

      Repo.query!(
        ~s|INSERT INTO custom_attribute_definitions (id, attribute_key, account_id, attribute_model, attribute_display_type, attribute_values, created_at, updated_at) VALUES ($1, 'category', $2, 1, 6, '["gold", "silver"]', $3, $3)|,
        [account_id, account_id, @created]
      )

      Repo.query!(
        "INSERT INTO canned_responses (id, account_id, short_code, content, created_at, updated_at) VALUES ($1, $2, 'hello', 'Welcome', $3, $3)",
        [account_id, account_id, @created]
      )

      Repo.query!(
        "INSERT INTO notes (id, account_id, contact_id, content, created_at, updated_at) VALUES ($1, $2, 8001, 'Note', $3, $3)",
        [account_id, account_id, @created]
      )

      Repo.query!(
        "INSERT INTO working_hours (id, inbox_id, account_id, day_of_week, open_all_day, created_at, updated_at) VALUES ($1, 9001, $2, 0, true, $3, $3)",
        [account_id, account_id, @created]
      )
    end

    account = %Account{id: 7001}
    assert [%{id: 7001, color: "#1f93ff", created_at: @created}] = Contacts.list_labels(account)

    assert [
             %{
               id: 7001,
               attribute_model: :contact_attribute,
               attribute_display_type: :list,
               attribute_values: ["gold", "silver"]
             }
           ] = Contacts.list_custom_attribute_definitions(account)

    assert [%{id: 7001, short_code: "hello", created_at: @created}] =
             Conversations.list_canned_responses(account)

    assert [%{id: 7001, user_id: nil}] = Contacts.list_notes(account, 8001)
    assert [] = Contacts.list_notes(account, 8002)

    assert [%{id: 7001, day_of_week: 0, open_all_day: true}] =
             Inboxes.list_working_hours(account, 9001)

    assert [] = Inboxes.list_working_hours(account, 9002)
  end

  test "unique keys follow upstream scope and permit null titles" do
    for {id, title, account_id} <- [
          {8001, "vip", 7001},
          {8002, "vip", 7002},
          {8003, nil, 7001},
          {8004, nil, 7001}
        ] do
      Repo.query!(
        "INSERT INTO labels (id, title, account_id, created_at, updated_at) VALUES ($1, $2, $3, $4, $4)",
        [id, title, account_id, @created]
      )
    end

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Repo.query(
               "INSERT INTO labels (title, account_id, created_at, updated_at) VALUES ('vip', 7001, $1, $1)",
               [@created]
             )
  end
end
