defmodule Chatwooter.Platform.EmailTemplate do
  @moduledoc "Read mapping of upstream email_templates; stored values are preserved."
  use Ecto.Schema

  schema "email_templates" do
    field :name, :string
    field :body, :string
    field :account_id, :integer
    field :template_type, :integer
    field :locale, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
    field :inbox_id, :integer
  end
end
