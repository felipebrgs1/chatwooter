defmodule Chatwooter.Accounts.AccountSamlSetting do
  @moduledoc "Read mapping of upstream account_saml_settings; stored values are preserved."
  use Ecto.Schema

  schema "account_saml_settings" do
    field :account_id, :integer
    field :sso_url, :string
    field :certificate, :string, redact: true
    field :sp_entity_id, :string
    field :idp_entity_id, :string
    field :role_mappings, Chatwooter.Types.JsonValue
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
