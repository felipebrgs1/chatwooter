# Imagem de produção: o Go serve a API e o build do dashboard no mesmo domínio (o cookie de sessão é same-site).
# Na subida aplica as migrations e então serve. Dev continua no docker-compose.yml (Dockerfile.dev).

FROM oven/bun:1 AS web
WORKDIR /app/web
COPY web/package.json web/bun.lock ./
RUN bun install --frozen-lockfile
COPY web/ ./
RUN bun run build

FROM golang:1.27 AS server
WORKDIR /app/server
COPY server/go.mod server/go.sum ./
RUN go mod download
COPY server/ ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/chatwooter ./cmd/chatwooter

FROM alpine:3
RUN apk add --no-cache ca-certificates tzdata \
    && adduser -D -H -u 10001 chatwooter \
    && mkdir -p /data/storage && chown chatwooter /data/storage
COPY --from=server /out/chatwooter /usr/local/bin/chatwooter
COPY --from=web /app/web/dist /app/web
ENV PORT=4000 \
    WEB_DIR=/app/web \
    UPLOADS_DIR=/data/storage \
    COOKIE_SECURE=true
USER chatwooter
VOLUME /data/storage
EXPOSE 4000
HEALTHCHECK --interval=10s --timeout=3s --retries=5 CMD wget -qO- http://127.0.0.1:${PORT}/health || exit 1
CMD ["sh", "-c", "chatwooter migrate && exec chatwooter serve"]
