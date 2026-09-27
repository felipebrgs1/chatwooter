Postgrex.Types.define(
  Chatwooter.PostgresTypes,
  Ecto.Adapters.Postgres.extensions() ++ [Pgvector.Extensions.Vector],
  []
)
