defmodule Chatwooter.Contacts.CustomAttributeDefinition do
  @moduledoc "Read-compatible mapping of upstream custom_attribute_definitions; IDs and timestamps are preserved."
  use Ecto.Schema

  schema "custom_attribute_definitions" do
    field :attribute_display_name, :string
    field :attribute_key, :string

    field :attribute_display_type, Ecto.Enum,
      values: [
        text: 0,
        number: 1,
        currency: 2,
        percent: 3,
        link: 4,
        date: 5,
        list: 6,
        checkbox: 7
      ],
      default: :text

    field :default_value, :integer

    field :attribute_model, Ecto.Enum,
      values: [conversation_attribute: 0, contact_attribute: 1, company_attribute: 2],
      default: :conversation_attribute

    field :attribute_description, :string
    field :attribute_values, Chatwooter.Contacts.AttributeValues, default: []
    field :regex_pattern, :string
    field :regex_cue, :string
    belongs_to :account, Chatwooter.Accounts.Account
    timestamps(type: :naive_datetime_usec, inserted_at: :created_at)
  end
end
