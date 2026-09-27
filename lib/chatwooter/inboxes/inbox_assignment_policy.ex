defmodule Chatwooter.Inboxes.InboxAssignmentPolicy do
  @moduledoc "Read mapping of upstream inbox_assignment_policies; stored values are preserved."
  use Ecto.Schema

  schema "inbox_assignment_policies" do
    field :inbox_id, :integer
    field :assignment_policy_id, :integer
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
