defmodule Chatwooter.Platform.Article do
  @moduledoc "Read mapping of upstream articles; help center compatibility without feature activation."
  use Ecto.Schema

  schema "articles" do
    field :account_id, :integer
    field :portal_id, :integer
    field :category_id, :integer
    field :folder_id, :integer
    field :status, :integer
    field :views, :integer
    field :author_id, :integer
    field :associated_article_id, :integer
    field :position, :integer
    field :title, :string
    field :description, :string
    field :content, :string
    field :slug, :string
    field :locale, :string
    field :draft_title, :string
    field :draft_content, :string
    field :meta, :map
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
