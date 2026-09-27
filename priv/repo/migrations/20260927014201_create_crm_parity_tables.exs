defmodule Chatwooter.Repo.Migrations.CreateCrmParityTables do
  use Ecto.Migration

  def change do
    # Preserve the upstream absence of foreign keys to accept the same restored data.
    create table(:labels) do
      add :title, :varchar
      add :description, :text
      add :color, :varchar, default: "#1f93ff", null: false
      add :show_on_sidebar, :boolean
      add :account_id, :bigint
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:labels, [:account_id], name: :index_labels_on_account_id)

    create unique_index(:labels, [:title, :account_id],
             name: :index_labels_on_title_and_account_id
           )

    create table(:notes) do
      add :content, :text, null: false
      add :account_id, :bigint, null: false
      add :contact_id, :bigint, null: false
      add :user_id, :bigint
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:notes, [:account_id], name: :index_notes_on_account_id)
    create index(:notes, [:contact_id], name: :index_notes_on_contact_id)
    create index(:notes, [:user_id], name: :index_notes_on_user_id)

    create table(:canned_responses, primary_key: [name: :id, type: :serial]) do
      add :account_id, :integer, null: false
      add :short_code, :varchar
      add :content, :text
      add :created_at, :timestamp, null: false
      add :updated_at, :timestamp, null: false
    end

    create table(:custom_attribute_definitions) do
      add :attribute_display_name, :varchar
      add :attribute_key, :varchar
      add :attribute_display_type, :integer, default: 0
      add :default_value, :integer
      add :attribute_model, :integer, default: 0
      add :account_id, :bigint
      add :attribute_description, :text
      add :attribute_values, :jsonb, default: fragment("'[]'::jsonb")
      add :regex_pattern, :varchar
      add :regex_cue, :varchar
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:custom_attribute_definitions, [:account_id],
             name: :index_custom_attribute_definitions_on_account_id
           )

    create unique_index(
             :custom_attribute_definitions,
             [:attribute_key, :attribute_model, :account_id], name: :attribute_key_model_index)

    create table(:working_hours) do
      add :inbox_id, :bigint
      add :account_id, :bigint
      add :day_of_week, :integer, null: false
      add :closed_all_day, :boolean, default: false
      add :open_hour, :integer
      add :open_minutes, :integer
      add :close_hour, :integer
      add :close_minutes, :integer
      add :open_all_day, :boolean, default: false
      add :created_at, :"timestamp(6)", null: false
      add :updated_at, :"timestamp(6)", null: false
    end

    create index(:working_hours, [:account_id], name: :index_working_hours_on_account_id)
    create index(:working_hours, [:inbox_id], name: :index_working_hours_on_inbox_id)
  end
end
