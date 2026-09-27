defmodule Chatwooter.Imports.ImportRun do
  @moduledoc "One destination account is bound to one upstream account for resumable imports."

  use Ecto.Schema
  import Ecto.Changeset

  schema "import_runs" do
    field :source_account_id, :integer
    field :status, Ecto.Enum, values: [:pending, :running, :completed, :failed], default: :pending
    field :attempts, :integer, default: 0
    field :processed_count, :integer, default: 0
    field :failed_count, :integer, default: 0

    belongs_to :account, Chatwooter.Accounts.Account
    has_many :errors, Chatwooter.Imports.ImportError

    timestamps(type: :utc_datetime)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [:source_account_id])
    |> validate_required([:source_account_id])
    |> validate_number(:source_account_id, greater_than: 0)
    |> foreign_key_constraint(:account_id)
    |> unique_constraint(:account_id)
    |> check_constraint(:source_account_id, name: :import_runs_valid_state)
  end
end
