defmodule Chatwooter.ContactsTest do
  @moduledoc "CRUD de contatos do CRM (cadastro manual com telefone/email)."
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Contacts}
  alias Chatwooter.Contacts.Contact

  setup do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)
    other_owner = insert(:user)
    {:ok, other_account} = Accounts.create_account(%{name: "Other"}, other_owner)
    %{account: account, other_account: other_account}
  end

  test "list_contacts/1 returns only the account contacts", %{
    account: account,
    other_account: other_account
  } do
    {:ok, _} = Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511911111111"})

    {:ok, _} =
      Contacts.create_contact(other_account, %{name: "João", phone_number: "+5511922222222"})

    assert [%Contact{name: "Maria"}] = Contacts.list_contacts(account)
  end

  test "create_contact/2 creates with name, phone and email", %{account: account} do
    assert {:ok,
            %Contact{name: "Maria", phone_number: "+5511911111111", email: "maria@example.com"}} =
             Contacts.create_contact(account, %{
               name: "Maria",
               phone_number: "+5511911111111",
               email: "maria@example.com"
             })
  end

  test "create_contact/2 requires name and rejects invalid email", %{account: account} do
    assert {:error, %Ecto.Changeset{} = changeset} =
             Contacts.create_contact(account, %{phone_number: "+5511911111111"})

    assert %{name: ["can't be blank"]} = errors_on(changeset)

    assert {:error, %Ecto.Changeset{} = changeset} =
             Contacts.create_contact(account, %{name: "Maria", email: "not-an-email"})

    assert %{email: [_]} = errors_on(changeset)
  end

  test "create_contact/2 rejects duplicated phone inside the account", %{account: account} do
    {:ok, _} =
      Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511911111111"})

    assert {:error, %Ecto.Changeset{} = changeset} =
             Contacts.create_contact(account, %{name: "Outra", phone_number: "+5511911111111"})

    assert %{phone_number: [_]} = errors_on(changeset)
  end

  test "create_contact/2 allows the same phone in another account", %{
    account: account,
    other_account: other_account
  } do
    {:ok, _} =
      Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511911111111"})

    assert {:ok, _} =
             Contacts.create_contact(other_account, %{
               name: "Maria 2",
               phone_number: "+5511911111111"
             })
  end

  test "update_contact/2 updates and validates", %{account: account} do
    {:ok, contact} =
      Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511911111111"})

    assert {:ok, %Contact{name: "Maria Silva"}} =
             Contacts.update_contact(contact, %{name: "Maria Silva"})

    assert {:error, %Ecto.Changeset{}} =
             Contacts.update_contact(contact, %{name: "X"})
  end

  test "delete_contact/1 removes the contact", %{account: account} do
    {:ok, contact} =
      Contacts.create_contact(account, %{name: "Maria", phone_number: "+5511911111111"})

    assert {:ok, %Contact{}} = Contacts.delete_contact(contact)
    assert [] = Contacts.list_contacts(account)
  end

  test "get_contact!/2 raises for contacts of another account", %{
    account: account,
    other_account: other_account
  } do
    {:ok, contact} =
      Contacts.create_contact(other_account, %{name: "João", phone_number: "+5511922222222"})

    assert_raise Ecto.NoResultsError, fn -> Contacts.get_contact!(account, contact.id) end
  end
end
