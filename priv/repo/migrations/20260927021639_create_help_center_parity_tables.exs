defmodule Chatwooter.Repo.Migrations.CreateHelpCenterParityTables do
  use Ecto.Migration

  def change do
    create table(:portals) do
      add :account_id, :integer, null: false
      add :name, :varchar, null: false
      add :slug, :varchar, null: false
      add :custom_domain, :varchar
      add :color, :varchar
      add :homepage_link, :varchar
      add :page_title, :varchar
      add :header_text, :text
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :config, :jsonb, default: fragment("'{\"allowed_locales\":[\"en\"]}'::jsonb")
      add :archived, :boolean, default: false
      add :channel_web_widget_id, :bigint
      add :ssl_settings, :jsonb, default: fragment("'{}'::jsonb"), null: false
    end

    create index(:portals, [:channel_web_widget_id],
             name: :index_portals_on_channel_web_widget_id
           )

    create unique_index(:portals, [:custom_domain], name: :index_portals_on_custom_domain)
    create unique_index(:portals, [:slug], name: :index_portals_on_slug)

    alter table(:inboxes) do
      add :portal_id, references(:portals)
    end

    create index(:inboxes, [:portal_id], name: :index_inboxes_on_portal_id)

    create table(:portals_members, primary_key: false) do
      add :portal_id, :bigint, null: false
      add :user_id, :bigint, null: false
    end

    create unique_index(:portals_members, [:portal_id, :user_id],
             name: :index_portals_members_on_portal_id_and_user_id
           )

    create index(:portals_members, [:portal_id], name: :index_portals_members_on_portal_id)
    create index(:portals_members, [:user_id], name: :index_portals_members_on_user_id)

    create table(:categories) do
      add :account_id, :integer, null: false
      add :portal_id, :integer, null: false
      add :name, :varchar
      add :description, :text
      add :position, :integer
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :locale, :varchar, default: "en"
      add :slug, :varchar, null: false
      add :parent_category_id, :bigint
      add :associated_category_id, :bigint
      add :icon, :varchar, default: ""
      add :icon_color, :varchar, default: ""
    end

    create index(:categories, [:associated_category_id],
             name: :index_categories_on_associated_category_id
           )

    create index(:categories, [:locale, :account_id],
             name: :index_categories_on_locale_and_account_id
           )

    create index(:categories, [:locale], name: :index_categories_on_locale)

    create index(:categories, [:parent_category_id],
             name: :index_categories_on_parent_category_id
           )

    create unique_index(:categories, [:slug, :locale, :portal_id],
             name: :index_categories_on_slug_and_locale_and_portal_id
           )

    create table(:articles) do
      add :account_id, :integer, null: false
      add :portal_id, :integer, null: false
      add :category_id, :integer
      add :folder_id, :integer
      add :title, :varchar
      add :description, :text
      add :content, :text
      add :status, :integer
      add :views, :integer
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
      add :author_id, :bigint
      add :associated_article_id, :bigint
      add :meta, :jsonb, default: fragment("'{}'::jsonb")
      add :slug, :varchar, null: false
      add :position, :integer
      add :locale, :varchar, default: "en", null: false
      add :draft_title, :varchar
      add :draft_content, :text
    end

    create index(:articles, [:account_id], name: :index_articles_on_account_id)

    create index(:articles, [:associated_article_id],
             name: :index_articles_on_associated_article_id
           )

    create index(:articles, [:author_id], name: :index_articles_on_author_id)
    create index(:articles, [:portal_id], name: :index_articles_on_portal_id)
    create unique_index(:articles, [:slug], name: :index_articles_on_slug)
    create index(:articles, [:status], name: :index_articles_on_status)
    create index(:articles, [:views], name: :index_articles_on_views)

    create table(:related_categories) do
      add :category_id, :bigint
      add :related_category_id, :bigint
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create unique_index(:related_categories, [:category_id, :related_category_id],
             name: :index_related_categories_on_category_id_and_related_category_id
           )

    create unique_index(:related_categories, [:related_category_id, :category_id],
             name: :index_related_categories_on_related_category_id_and_category_id
           )
  end
end
