defmodule Chatwooter.ConversationFiltersTest do
  use Chatwooter.DataCase, async: true
  import Chatwooter.AccountsFixtures
  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes, Repo}

  setup do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Filters"}, user)
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Sales", channel_type: "whatsapp"})

    conversations =
      for {name, status, priority, assignee} <- [
            {"Open", :open, 1, user.id},
            {"Resolved", :resolved, 3, nil},
            {"Pending", :pending, 3, user.id}
          ] do
        {:ok, contact} = Contacts.get_or_create_contact(account, %{name: name})
        {:ok, conv} = Conversations.open_conversation(account, inbox, contact, %{source_id: name})

        Repo.update!(
          Ecto.Changeset.change(conv, status: status, priority: priority, assignee_id: assignee)
        )
      end

    %{user: user, account: account, inbox: inbox, conversations: conversations}
  end

  defp condition(key, values, operator \\ "equal_to", join \\ nil) do
    %{
      "attribute_key" => key,
      "values" => values,
      "filter_operator" => operator,
      "query_operator" => join
    }
  end

  defp filter(ctx, conditions) do
    Conversations.filter_conversations(ctx.account, %{"payload" => conditions},
      user_id: ctx.user.id
    )
  end

  test "matches multiple values and computes counts from the filtered result", ctx do
    [open, _, pending] = ctx.conversations

    assert {:ok, %{conversations: conversations, counts: %{mine: 2, unassigned: 0, all: 2}}} =
             filter(ctx, [condition("status", ["open", "pending"])])

    assert Enum.sort(Enum.map(conversations, & &1.id)) == Enum.sort([open.id, pending.id])
  end

  test "custom attributes are validated against this account's conversation definitions", ctx do
    [a, b, c] = ctx.conversations

    for {key, type} <- [
          {"plan", :text},
          {"amount", :number},
          {"paid", :checkbox},
          {"due", :date},
          {"tier", :list},
          {"url", :link}
        ] do
      Repo.insert!(%Contacts.CustomAttributeDefinition{
        account_id: ctx.account.id,
        attribute_key: key,
        attribute_display_name: key,
        attribute_display_type: type,
        attribute_model: :conversation_attribute
      })
    end

    Repo.update!(
      Ecto.Changeset.change(a,
        custom_attributes: %{
          "plan" => "GOLD",
          "amount" => 12.5,
          "paid" => true,
          "due" => "2030-01-01",
          "tier" => "Premium",
          "url" => "https://EXAMPLE.test"
        }
      )
    )

    Repo.update!(
      Ecto.Changeset.change(b,
        custom_attributes: %{
          "plan" => "Silver",
          "amount" => "4.25",
          "paid" => false,
          "due" => "2020-01-01"
        }
      )
    )

    for row <- [
          condition("plan", ["gold"]),
          condition("plan", ["ol"], "contains"),
          condition("amount", ["10.5"], "is_greater_than"),
          condition("paid", ["true"]),
          condition("due", ["2029-01-01"], "is_greater_than"),
          condition("tier", ["premium"]),
          condition("url", ["https://example.test"])
        ] do
      assert {:ok, %{conversations: [match]}} = filter(ctx, [row])
      assert match.id == a.id
    end

    assert {:ok, %{conversations: matches}} =
             filter(ctx, [condition("plan", ["gold"], "not_equal_to")])

    assert Enum.sort(Enum.map(matches, & &1.id)) == Enum.sort([b.id, c.id])
    assert {:ok, %{counts: %{all: 1}}} = filter(ctx, [condition("amount", ["4.25"])])
    assert {:ok, %{counts: %{all: 2}}} = filter(ctx, [condition("paid", [], "is_present")])
    assert {:ok, %{counts: %{all: 1}}} = filter(ctx, [condition("due", ["1"], "days_before")])

    for row <- [
          condition("missing", ["gold"]),
          condition("amount", ["NaN"]),
          condition("amount", ["invalid"]),
          condition("due", ["2030-02-30"]),
          condition("paid", ["maybe"])
        ] do
      assert {:error, _} = filter(ctx, [row])
    end
  end

  test "invalid restored custom scalar values do not crash the filtered list", ctx do
    [a | _] = ctx.conversations

    for {key, type} <- [{"amount", :number}, {"paid", :checkbox}, {"due", :date}] do
      Repo.insert!(%Contacts.CustomAttributeDefinition{
        account_id: ctx.account.id,
        attribute_key: key,
        attribute_display_name: key,
        attribute_display_type: type,
        attribute_model: :conversation_attribute
      })
    end

    Repo.update!(
      Ecto.Changeset.change(a,
        custom_attributes: %{"amount" => "bad-number", "paid" => "maybe", "due" => "2030-02-30"}
      )
    )

    for {key, value} <- [{"amount", "10"}, {"paid", "true"}, {"due", "2030-01-01"}] do
      assert {:ok, %{counts: %{all: 0}}} = filter(ctx, [condition(key, [value])])
      assert {:ok, %{counts: %{all: 3}}} = filter(ctx, [condition(key, [], "is_not_present")])
    end
  end

  test "custom definitions cannot leak between accounts or contact and conversation models",
       ctx do
    foreign = Repo.insert!(%Accounts.Account{name: "Foreign custom attributes"})

    for {account_id, model, key} <- [
          {foreign.id, :conversation_attribute, "foreign_key"},
          {ctx.account.id, :contact_attribute, "contact_key"}
        ] do
      Repo.insert!(%Contacts.CustomAttributeDefinition{
        account_id: account_id,
        attribute_model: model,
        attribute_key: key,
        attribute_display_name: key
      })

      assert {:error, _} = filter(ctx, [condition(key, ["value"])])
    end
  end

  test "additional attribute equality stays case sensitive while containment ignores case", ctx do
    [a, b, _] = ctx.conversations

    Repo.update!(
      Ecto.Changeset.change(a,
        additional_attributes: %{
          "browser_language" => "en",
          "referer" => "https://EXAMPLE.com/help",
          "conversation_language" => "pt",
          "mail_subject" => "Help with billing"
        }
      )
    )

    Repo.update!(
      Ecto.Changeset.change(b,
        additional_attributes: %{
          "browser_language" => "EN",
          "referer" => "https://other.test/faq"
        }
      )
    )

    assert {:ok, %{conversations: [match]}} = filter(ctx, [condition("browser_language", ["en"])])
    assert match.id == a.id

    assert {:ok, %{counts: %{all: 2}}} =
             filter(ctx, [condition("browser_language", ["en", "EN"])])

    assert {:ok, %{conversations: [match]}} =
             filter(ctx, [condition("referer", ["example.com", "missing"], "contains")])

    assert match.id == a.id

    assert {:ok, %{conversations: [match]}} =
             filter(ctx, [condition("referer", ["EXAMPLE"], "does_not_contain")])

    assert match.id == b.id
    assert {:ok, %{counts: %{all: 1}}} = filter(ctx, [condition("conversation_language", ["pt"])])

    assert {:ok, %{counts: %{all: 1}}} =
             filter(ctx, [condition("mail_subject", ["BILLING"], "contains")])

    for row <- [
          condition("browser_language", ["en"], "contains"),
          condition("referer", ["x"], "is_present"),
          condition("referer", [%{"bad" => "value"}])
        ] do
      assert {:error, _} = filter(ctx, [row])
    end
  end

  test "assignee presence includes bot ownership like Chatwoot", ctx do
    [a, b, _] = ctx.conversations
    Repo.update!(Ecto.Changeset.change(a, assignee_id: nil, assignee_agent_bot_id: 7))
    assert {:ok, %{counts: %{all: 2}}} = filter(ctx, [condition("assignee_id", [], "is_present")])

    assert {:ok, %{conversations: [match]}} =
             filter(ctx, [condition("assignee_id", [], "is_not_present")])

    assert match.id == b.id
  end

  test "date comparisons use whole local days and accept legacy queries without timezone", ctx do
    [a, b, c] = ctx.conversations

    for {conv, time} <- [
          {a, ~U[2026-03-29 02:59:59.000000Z]},
          {b, ~U[2026-03-29 03:00:00.000000Z]},
          {c, ~U[2026-03-30 03:00:00.000000Z]}
        ] do
      Repo.update!(Ecto.Changeset.change(conv, inserted_at: time, last_activity_at: time))
    end

    before =
      condition("created_at", ["2026-03-29"], "is_less_than")
      |> Map.put("timezone", "America/Fortaleza")

    after_day =
      condition("last_activity_at", ["2026-03-29"], "is_greater_than")
      |> Map.put("timezone", "America/Fortaleza")

    assert {:ok, %{conversations: [match]}} = filter(ctx, [before])
    assert match.id == a.id
    assert {:ok, %{conversations: [match]}} = filter(ctx, [after_day])
    assert match.id == c.id

    assert {:ok, %{counts: %{all: 1}}} =
             filter(ctx, [condition("created_at", ["2026-03-29"], "is_greater_than")])
  end

  test "local day boundaries follow daylight saving rather than a fixed offset", ctx do
    [a, b, c] = ctx.conversations

    for {conv, time} <- [
          {a, ~U[2026-03-29 21:59:59.000000Z]},
          {b, ~U[2026-03-29 22:00:00.000000Z]},
          {c, ~U[2026-03-29 23:00:00.000000Z]}
        ] do
      Repo.update!(Ecto.Changeset.change(conv, inserted_at: time))
    end

    predicate =
      condition("created_at", ["2026-03-29"], "is_greater_than")
      |> Map.put("timezone", "Europe/Berlin")

    assert {:ok, %{conversations: matches}} = filter(ctx, [predicate])
    assert Enum.sort(Enum.map(matches, & &1.id)) == Enum.sort([b.id, c.id])
  end

  test "days before uses a local midnight cutoff and rejects invalid dates, days and zones",
       ctx do
    [old | _] = ctx.conversations

    Repo.update!(
      Ecto.Changeset.change(old, inserted_at: DateTime.add(DateTime.utc_now(), -1000, :day))
    )

    query =
      condition("created_at", ["1"], "days_before") |> Map.put("timezone", "America/Fortaleza")

    assert {:ok, %{conversations: [match]}} = filter(ctx, [query])
    assert match.id == old.id

    for row <- [
          condition("created_at", ["2026-02-30"], "is_less_than"),
          condition("created_at", ["1.5"], "days_before"),
          condition("created_at", [1.0], "days_before"),
          condition("created_at", ["0"], "days_before"),
          condition("created_at", ["999"], "days_before"),
          Map.put(query, "timezone", "Invalid/Zone"),
          Map.put(query, "timezone", nil),
          Map.put(query, "timezone", "UTC'; DROP TABLE users; --")
        ] do
      assert {:error, _} = filter(ctx, [row])
    end
  end

  test "AND binds before OR and OR cannot escape the account", ctx do
    [open, _, pending] = ctx.conversations
    foreign = Repo.insert!(%Accounts.Account{name: "Foreign"})

    {:ok, foreign_inbox} =
      Inboxes.create_inbox(foreign, %{name: "Other", channel_type: "whatsapp"})

    {:ok, contact} = Contacts.get_or_create_contact(foreign, %{name: "Foreign"})

    {:ok, _} =
      Conversations.open_conversation(foreign, foreign_inbox, contact, %{source_id: "foreign"})

    assert {:ok, %{conversations: conversations}} =
             filter(ctx, [
               condition("status", ["open"], "equal_to", "or"),
               condition("priority", ["urgent"], "equal_to", "and"),
               condition("assignee_id", [], "is_present")
             ])

    assert Enum.sort(Enum.map(conversations, & &1.id)) == Enum.sort([open.id, pending.id])
  end

  test "negative equality excludes null values like upstream SQL", ctx do
    assert {:ok, %{counts: %{all: 0}}} =
             filter(ctx, [condition("assignee_id", [ctx.user.id], "not_equal_to")])

    assert {:ok, %{counts: %{all: 1}}} =
             filter(ctx, [condition("assignee_id", [], "is_not_present")])

    assert {:ok, %{counts: %{all: 3}}} = filter(ctx, [condition("status", ["all"])])
  end

  test "label equality uses any matching tag and presence ignores contact tags", ctx do
    [open, resolved, pending] = ctx.conversations
    tag = Repo.insert!(%Contacts.Tag{name: "vip"})

    for {id, type} <- [{open.id, "Conversation"}, {resolved.id, "Contact"}] do
      Repo.insert!(%Contacts.Tagging{
        tag_id: tag.id,
        taggable_id: id,
        taggable_type: type,
        context: "labels"
      })
    end

    assert {:ok, %{conversations: [match]}} = filter(ctx, [condition("labels", ["vip", "other"])])
    assert match.id == open.id
    assert {:ok, %{counts: %{all: 1}}} = filter(ctx, [condition("labels", [], "is_present")])

    assert {:ok, %{conversations: missing}} =
             filter(ctx, [condition("labels", ["vip"], "not_equal_to")])

    assert Enum.sort(Enum.map(missing, & &1.id)) == Enum.sort([resolved.id, pending.id])
  end

  test "rejects unknown keys, operators, values and invalid connectors", ctx do
    for payload <- [
          [condition("status; DROP TABLE users", ["open"])],
          [condition("status", ["unknown"])],
          [condition("status", ["open"], "contains")],
          [condition("team_id", ["not a number"])],
          [condition("status", [])],
          [condition("status", ["open"], "equal_to", "or")],
          [condition("status", ["open"], "equal_to", "xor"), condition("priority", ["high"])]
        ] do
      assert {:error, _} = filter(ctx, payload)
    end

    assert {:error, _} =
             Conversations.filter_conversations(ctx.account, %{"payload" => "invalid"},
               user_id: ctx.user.id
             )
  end
end
