-- name: GetInboxConfig :one
SELECT inbox_id, provider_config FROM chatwooter_inbox_configs WHERE inbox_id = $1;

-- name: ListInboxConfigs :many
SELECT inbox_id, provider_config FROM chatwooter_inbox_configs ORDER BY inbox_id;

-- name: UpsertInboxConfig :exec
INSERT INTO chatwooter_inbox_configs (inbox_id, provider_config) VALUES ($1, $2)
ON CONFLICT (inbox_id) DO UPDATE SET provider_config = EXCLUDED.provider_config;
