#!/bin/bash
# Dev entrypoint: deps -> db -> assets -> server. Idempotent, safe to re-run.
set -e

mix deps.get
mix ecto.create
mix ecto.migrate
mix assets.setup
mix assets.build

exec mix phx.server
