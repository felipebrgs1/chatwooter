# Chatwooter — produção (Dokploy / Docker).
# Multi-stage com imagens pré-compiladas (rápido em ARM64).
# Uso no Dokploy: Build Type = Dockerfile, Dockerfile Path = ./Dockerfile
ARG ELIXIR_VERSION=1.20.2
ARG OTP_VERSION=29.0
ARG DEBIAN_VERSION=trixie-20250910-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

WORKDIR /app

RUN apt-get update -y && apt-get install -y build-essential git curl ca-certificates && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

# Hex/Rebar primeiro (cache de layer)
RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV="prod"

# Deps primeiro para aproveitar cache
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir -p config && \
    mix deps.compile

# Código + assets
COPY priv priv
COPY lib lib
COPY assets assets
COPY config config

RUN mix assets.setup && \
    mix compile && \
    mix assets.deploy

# Release (usa config/runtime.exs; sem pasta rel/ customizada)
RUN mix release

# --- Runner ---
FROM ${RUNNER_IMAGE} AS runner

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

# pt_BR.UTF-8
RUN sed -i '/pt_BR.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG="pt_BR.UTF-8" \
    LANGUAGE="pt_BR:pt" \
    LC_ALL="pt_BR.UTF-8"

WORKDIR /app
RUN chown nobody /app

ENV MIX_ENV="prod"
ENV PHX_SERVER="true"

COPY --from=builder --chown=nobody:root /app/_build/prod/rel/chatwooter ./

USER nobody

# Dokploy injeta PORT; default 4000
ENV PORT="4000"
EXPOSE 4000

CMD ["/app/bin/chatwooter", "start"]
