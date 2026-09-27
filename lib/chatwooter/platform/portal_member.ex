defmodule Chatwooter.Platform.PortalMember do
  @moduledoc "Read mapping of upstream portals_members; help center compatibility without feature activation."
  use Ecto.Schema

  @primary_key false

  schema "portals_members" do
    field :portal_id, :integer
    field :user_id, :integer
  end
end
