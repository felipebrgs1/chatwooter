defmodule Chatwooter.Repo do
  use Ecto.Repo,
    otp_app: :chatwooter,
    adapter: Ecto.Adapters.Postgres
end
