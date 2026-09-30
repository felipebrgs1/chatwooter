-- name: ListLabels :many
-- Label tem default_scope order(:title) no Chatwoot.
SELECT id, title, description, color, show_on_sidebar FROM labels WHERE account_id = $1 ORDER BY title;
