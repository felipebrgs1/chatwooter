defmodule Chatwooter.CompaniesTest do
  @moduledoc "Empresas estilo Chatwoot: CRUD + vínculo com contatos."
  use Chatwooter.DataCase

  import Chatwooter.Factory

  alias Chatwooter.{Accounts, Companies, Contacts}

  setup do
    owner = insert(:user)
    {:ok, account} = Accounts.create_account(%{name: "Acme"}, owner)
    other_owner = insert(:user)
    {:ok, other_account} = Accounts.create_account(%{name: "Other"}, other_owner)
    %{account: account, other_account: other_account}
  end

  test "create_company/2 creates with name, domain and description", %{account: account} do
    assert {:ok, company} =
             Companies.create_company(account, %{
               name: "Acme Inc",
               domain: "acme.inc",
               description: "Best customer"
             })

    assert company.name == "Acme Inc"
    assert company.domain == "acme.inc"
  end

  test "create_company/2 requires name and validates domain", %{account: account} do
    assert {:error, %Ecto.Changeset{} = changeset} =
             Companies.create_company(account, %{domain: "acme.inc"})

    assert %{name: ["can't be blank"]} = errors_on(changeset)

    assert {:error, %Ecto.Changeset{} = changeset} =
             Companies.create_company(account, %{name: "Acme", domain: "not a domain"})

    assert %{domain: [_]} = errors_on(changeset)
  end

  test "create_company/2 rejects duplicated domain inside the account", %{account: account} do
    {:ok, _} = Companies.create_company(account, %{name: "Acme", domain: "acme.inc"})

    assert {:error, %Ecto.Changeset{} = changeset} =
             Companies.create_company(account, %{name: "Other", domain: "acme.inc"})

    assert %{domain: [_]} = errors_on(changeset)
  end

  test "create_company/2 allows the same domain in another account", %{
    account: account,
    other_account: other_account
  } do
    {:ok, _} = Companies.create_company(account, %{name: "Acme", domain: "acme.inc"})

    assert {:ok, _} =
             Companies.create_company(other_account, %{name: "Acme 2", domain: "acme.inc"})
  end

  test "list_companies/1 is scoped and counts contacts", %{
    account: account,
    other_account: other_account
  } do
    {:ok, acme} = Companies.create_company(account, %{name: "Acme"})
    {:ok, _} = Companies.create_company(other_account, %{name: "Other Co"})
    {:ok, contact} = Contacts.create_contact(account, %{name: "Maria"})
    {:ok, _} = Contacts.assign_company(contact, acme)

    assert [%{name: "Acme", contacts_count: 1}] = Companies.list_companies(account)
  end

  test "get_company!/2 raises for another account", %{
    account: account,
    other_account: other_account
  } do
    {:ok, company} = Companies.create_company(other_account, %{name: "Other Co"})

    assert_raise Ecto.NoResultsError, fn -> Companies.get_company!(account, company.id) end
  end

  test "update_company/2 renames and syncs linked contacts", %{account: account} do
    {:ok, company} = Companies.create_company(account, %{name: "Acme"})
    {:ok, contact} = Contacts.create_contact(account, %{name: "Maria"})
    {:ok, _} = Contacts.assign_company(contact, company)

    assert {:ok, %{name: "Acme Inc"}} =
             Companies.update_company(company, %{name: "Acme Inc"})

    contact = Contacts.get_contact!(account, contact.id)
    assert contact.additional_attributes["company_name"] == "Acme Inc"
  end

  test "set/remove_custom_attribute/2 manages custom attributes", %{account: account} do
    {:ok, company} = Companies.create_company(account, %{name: "Acme"})

    assert {:ok, %{custom_attributes: %{"industry" => "tech"}}} =
             Companies.set_custom_attribute(company, "industry", "tech")

    company = Companies.get_company!(account, company.id)

    assert {:ok, %{custom_attributes: %{}}} =
             Companies.remove_custom_attribute(company, "industry")
  end

  test "delete_company/1 unlinks contacts", %{account: account} do
    {:ok, company} = Companies.create_company(account, %{name: "Acme"})
    {:ok, contact} = Contacts.create_contact(account, %{name: "Maria"})
    {:ok, _} = Contacts.assign_company(contact, company)

    assert {:ok, _} = Companies.delete_company(company)
    assert [] = Companies.list_companies(account)

    contact = Contacts.get_contact!(account, contact.id)
    assert contact.company_id == nil
  end
end
