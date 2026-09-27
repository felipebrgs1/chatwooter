defmodule Chatwooter.ContactDetailsTest do
  use Chatwooter.DataCase, async: true

  import Chatwooter.AccountsFixtures

  alias Chatwooter.{Accounts, Contacts, Conversations, Inboxes, Repo}
  alias Chatwooter.Contacts.{Contact, ContactInbox, CustomAttributeDefinition, Label, Note}
  alias Chatwooter.Conversations.Conversation
  alias Chatwooter.Platform.ContactMerge

  setup do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, user)
    {:ok, inbox} = Inboxes.create_inbox(account, %{name: "Vendas", channel_type: "whatsapp"})

    {:ok, maria} =
      Contacts.get_or_create_contact(account, %{name: "Maria", phone_number: "+5511900000001"})

    %{user: user, account: account, inbox: inbox, maria: maria}
  end

  defp label(account, title) do
    Repo.insert!(%Label{account_id: account.id, title: title, color: "#ff0000"})
  end

  describe "labels" do
    test "adds and removes contact labels (acts_as_taggable :labels)", %{
      account: account,
      maria: maria
    } do
      label(account, "vip")
      label(account, "lead")

      assert Contacts.list_contact_labels(maria) == []

      {:ok, ["vip"]} = Contacts.add_contact_label(maria, "vip")
      {:ok, ["lead", "vip"]} = Contacts.add_contact_label(maria, "lead")
      {:ok, ["lead", "vip"]} = Contacts.add_contact_label(maria, "vip")
      assert Contacts.list_contact_labels(maria) == ["lead", "vip"]

      {:ok, ["lead"]} = Contacts.remove_contact_label(maria, "vip")
      assert Contacts.list_contact_labels(maria) == ["lead"]
    end

    test "labels of one contact don't leak to another", %{account: account, maria: maria} do
      label(account, "vip")

      {:ok, joao} =
        Contacts.get_or_create_contact(account, %{name: "João", phone_number: "+5511900000002"})

      {:ok, _} = Contacts.add_contact_label(maria, "vip")

      assert Contacts.list_contact_labels(joao) == []
    end
  end

  describe "notes" do
    test "creates, lists newest first and deletes notes", %{
      account: account,
      user: user,
      maria: maria
    } do
      {:ok, first} = Contacts.create_note(account, maria, user, "Primeira")
      {:ok, second} = Contacts.create_note(account, maria, user, "Segunda")

      assert [%Note{id: id2, user: %{id: user_id}}, %Note{id: id1}] =
               Contacts.list_contact_notes(account, maria)

      assert {id2, id1, user_id} == {second.id, first.id, user.id}

      {:ok, _} = Contacts.delete_note(account, first.id)
      assert [%Note{id: ^id2}] = Contacts.list_contact_notes(account, maria)
    end

    test "rejects blank notes", %{account: account, user: user, maria: maria} do
      assert {:error, %Ecto.Changeset{}} = Contacts.create_note(account, maria, user, "  ")
    end
  end

  describe "custom attributes" do
    test "only contact attribute definitions are listed", %{account: account} do
      Repo.insert!(%CustomAttributeDefinition{
        account_id: account.id,
        attribute_key: "tier",
        attribute_display_name: "Tier",
        attribute_model: :contact_attribute
      })

      Repo.insert!(%CustomAttributeDefinition{
        account_id: account.id,
        attribute_key: "ticket",
        attribute_display_name: "Ticket",
        attribute_model: :conversation_attribute
      })

      assert [%{attribute_key: "tier"}] = Contacts.list_contact_attribute_definitions(account)
    end

    test "sets and clears a single custom attribute", %{maria: maria} do
      {:ok, maria} = Contacts.update_contact(maria, %{custom_attributes: %{"plan" => "pro"}})

      {:ok, maria} = Contacts.put_custom_attribute(maria, "tier", "gold")
      assert maria.custom_attributes == %{"plan" => "pro", "tier" => "gold"}

      {:ok, maria} = Contacts.delete_custom_attribute(maria, "plan")
      assert maria.custom_attributes == %{"tier" => "gold"}
    end
  end

  describe "media" do
    test "lists attachments shared in the contact's conversations, newest first", %{
      account: account,
      inbox: inbox,
      maria: maria
    } do
      {:ok, conv} = Conversations.open_conversation(account, inbox, maria, %{source_id: "1"})
      {:ok, msg} = Conversations.add_message(conv, %{content: "foto", content_type: "image"})

      {:ok, _} =
        Conversations.create_attachment(msg, %{
          file_type: "image",
          key: "a/1.jpg",
          url: "http://x/1.jpg"
        })

      assert [%{file_type: :image, message_id: message_id}] =
               Conversations.list_contact_attachments(account, maria)

      assert message_id == msg.id
    end
  end

  describe "merge" do
    test "moves conversations, inboxes, notes and messages to the primary contact", %{
      account: account,
      inbox: inbox,
      user: user,
      maria: maria
    } do
      {:ok, primary} =
        Contacts.get_or_create_contact(account, %{
          name: "Maria Silva",
          phone_number: "+5511900000009",
          email: "maria@acme.com"
        })

      {:ok, maria} =
        Contacts.update_contact(maria, %{
          identifier: "ext-1",
          custom_attributes: %{"tier" => "gold"},
          additional_attributes: %{"city" => "SP"}
        })

      {:ok, conv} = Conversations.open_conversation(account, inbox, maria, %{source_id: "1"})
      {:ok, _} = Contacts.create_note(account, maria, user, "Nota")

      assert {:ok, %Contact{} = merged} = ContactMerge.merge(account, primary, maria)

      refute Repo.get(Contact, maria.id)
      assert Repo.get!(Conversation, conv.id).contact_id == primary.id
      assert Repo.get_by!(ContactInbox, source_id: "1").contact_id == primary.id
      assert [%Note{content: "Nota"}] = Contacts.list_contact_notes(account, primary)

      # atributos do principal têm preferência; os vazios vêm do mesclado
      assert merged.name == "Maria Silva"
      assert merged.email == "maria@acme.com"
      assert merged.identifier == "ext-1"
      assert merged.custom_attributes == %{"tier" => "gold"}
      assert merged.additional_attributes["city"] == "SP"
    end

    test "refuses contacts from another account or the same contact", %{
      account: account,
      maria: maria
    } do
      other_user = user_fixture()
      {:ok, other_account} = Accounts.create_account(%{name: "Other"}, other_user)

      {:ok, stranger} =
        Contacts.get_or_create_contact(other_account, %{name: "Estranho", phone_number: "+1555"})

      assert {:error, :invalid_contacts} = ContactMerge.merge(account, maria, stranger)
      assert {:error, :invalid_contacts} = ContactMerge.merge(account, maria, maria)
    end
  end
end
