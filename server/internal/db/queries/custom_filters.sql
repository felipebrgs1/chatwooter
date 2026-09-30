-- name: ListCustomFilters :many
SELECT * FROM custom_filters
WHERE account_id = $1 AND user_id = $2 AND filter_type = $3 ORDER BY id;

-- name: GetCustomFilter :one
SELECT * FROM custom_filters
WHERE account_id = $1 AND user_id = $2 AND id = $3;

-- name: CountCustomFiltersOfUser :one
SELECT count(*) FROM custom_filters WHERE account_id = $1 AND user_id = $2;

-- name: CreateCustomFilter :one
INSERT INTO custom_filters (account_id, user_id, name, filter_type, query, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, now(), now())
RETURNING *;

-- name: UpdateCustomFilter :one
UPDATE custom_filters SET name = $4, filter_type = $5, query = $6, updated_at = now()
WHERE account_id = $1 AND user_id = $2 AND id = $3
RETURNING *;

-- name: DeleteCustomFilter :execrows
DELETE FROM custom_filters WHERE account_id = $1 AND user_id = $2 AND id = $3;
