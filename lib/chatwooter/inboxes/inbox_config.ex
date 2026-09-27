defmodule Chatwooter.Inboxes.InboxConfig do
  @moduledoc "Local adapter settings kept separate from the upstream inbox table."
  use Ecto.Schema

  @primary_key {:inbox_id, :id, autogenerate: false}
  schema "chatwooter_inbox_configs" do
    field :provider_config, :map, default: %{}, redact: true
  end
end
