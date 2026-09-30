-- name: InsertSession :exec
INSERT INTO chatwooter_sessions (user_id, token_hash, expires_at) VALUES ($1, $2, $3);

-- name: GetSessionUser :one
SELECT sqlc.embed(u)
FROM chatwooter_sessions s JOIN users u ON u.id = s.user_id
WHERE s.token_hash = $1 AND s.expires_at > (now() AT TIME ZONE 'utc');

-- name: DeleteSession :exec
DELETE FROM chatwooter_sessions WHERE token_hash = $1;

-- name: PurgeExpiredSessions :execrows
DELETE FROM chatwooter_sessions WHERE expires_at <= (now() AT TIME ZONE 'utc');
