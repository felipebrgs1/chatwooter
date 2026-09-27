defmodule Chatwooter.Platform.ActionMailboxInboundEmail do
  @moduledoc "Read mapping of upstream action_mailbox_inbound_emails; Rails compatibility only, without feature activation."
  use Ecto.Schema

  schema "action_mailbox_inbound_emails" do
    field :status, :integer
    field :message_id, :string
    field :message_checksum, :string
    field :created_at, :naive_datetime_usec
    field :updated_at, :naive_datetime_usec
  end
end
