-- name: CountCompanies :one
SELECT count(*) FROM companies
WHERE account_id = @account_id AND (sqlc.arg(search)::text = '' OR name ILIKE '%' || sqlc.arg(search)::text || '%' OR domain ILIKE '%' || sqlc.arg(search)::text || '%');

-- name: ListCompanies :many
SELECT * FROM companies
WHERE account_id = @account_id AND (sqlc.arg(search)::text = '' OR name ILIKE '%' || sqlc.arg(search)::text || '%' OR domain ILIKE '%' || sqlc.arg(search)::text || '%')
ORDER BY
 CASE WHEN @sort::text = 'name' THEN name END ASC,
 CASE WHEN @sort::text = '-name' THEN name END DESC,
 CASE WHEN @sort::text = 'domain' THEN domain END ASC,
 CASE WHEN @sort::text = '-domain' THEN domain END DESC,
 CASE WHEN @sort::text = 'created_at' THEN created_at END ASC,
 CASE WHEN @sort::text = '-created_at' THEN created_at END DESC,
 CASE WHEN @sort::text = 'last_activity_at' THEN last_activity_at END ASC NULLS LAST,
 CASE WHEN @sort::text = '-last_activity_at' THEN last_activity_at END DESC NULLS LAST,
 CASE WHEN @sort::text = 'contacts_count' THEN contacts_count END ASC NULLS LAST,
 CASE WHEN @sort::text = '-contacts_count' THEN contacts_count END DESC NULLS LAST,
 id ASC
LIMIT sqlc.arg(page_limit) OFFSET sqlc.arg(page_offset);

-- name: GetCompany :one
SELECT * FROM companies WHERE account_id = @account_id AND id = @id;

-- name: CreateCompany :one
INSERT INTO companies (account_id, name, domain, description, additional_attributes, custom_attributes, created_at, updated_at)
VALUES (@account_id, @name, sqlc.narg(domain), sqlc.narg(description), @additional_attributes, @custom_attributes, now(), now())
RETURNING *;
