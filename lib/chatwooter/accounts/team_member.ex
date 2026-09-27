defmodule Chatwooter.Accounts.TeamMember do
  @moduledoc "Vínculo entre uma equipe e um agente da mesma conta."

  use Ecto.Schema
  import Ecto.Changeset

  schema "team_members" do
    belongs_to :team, Chatwooter.Accounts.Team
    belongs_to :user, Chatwooter.Accounts.User

    timestamps(type: :naive_datetime_usec, inserted_at: :created_at)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:team_id, :user_id])
    |> validate_required([:team_id, :user_id])
    |> unique_constraint(:team_id, name: :index_team_members_on_team_id_and_user_id)
    |> foreign_key_constraint(:team_id)
    |> foreign_key_constraint(:user_id)
  end
end
