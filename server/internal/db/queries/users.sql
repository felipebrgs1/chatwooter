-- name: UsersByEmail :many
-- Até 2 linhas: basta para detectar e-mail ambíguo em dumps restaurados.
SELECT * FROM users WHERE lower(email) = lower($1) LIMIT 2;

-- name: GetUser :one
SELECT * FROM users WHERE id = $1;

-- name: GetUserByAccessToken :one
SELECT sqlc.embed(u)
FROM users u JOIN access_tokens t ON t.owner_id = u.id AND t.owner_type = 'User'
WHERE t.token = $1;

-- name: GetUserAccessToken :one
SELECT token FROM access_tokens WHERE owner_type = 'User' AND owner_id = $1 ORDER BY id LIMIT 1;

-- name: ListMemberships :many
SELECT au.account_id, a.name AS account_name, a.status AS account_status,
       a.custom_attributes AS account_custom_attributes,
       au.active_at, au.role, au.availability, au.auto_offline, au.inviter_id
FROM account_users au JOIN accounts a ON a.id = au.account_id
WHERE au.user_id = $1
ORDER BY au.account_id;

-- name: GetMembership :one
SELECT au.account_id, a.name AS account_name, a.status AS account_status,
       a.custom_attributes AS account_custom_attributes,
       au.active_at, au.role, au.availability, au.auto_offline, au.inviter_id
FROM account_users au JOIN accounts a ON a.id = au.account_id
WHERE au.user_id = $1 AND au.account_id = $2;
