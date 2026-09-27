defmodule Chatwooter.Accounts.Team do
  @moduledoc "Equipe vinculada a uma conta."

  use Ecto.Schema
  import Ecto.Changeset

  schema "teams" do
    field :name, :string
    field :description, :string
    field :allow_auto_assign, :boolean, default: true
    field :icon, :string, default: ""
    field :icon_color, :string, default: ""

    belongs_to :account, Chatwooter.Accounts.Account
    has_many :team_members, Chatwooter.Accounts.TeamMember

    timestamps(type: :naive_datetime_usec, inserted_at: :created_at)
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :description, :allow_auto_assign, :icon, :icon_color])
    |> validate_required([:name])
    |> unique_constraint(:name, name: :index_teams_on_name_and_account_id)
    |> foreign_key_constraint(:account_id)
  end
end
