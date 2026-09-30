-- name: ListTeams :many
-- is_member: o usuário da sessão está no time (_team.json.jbuilder).
SELECT t.id, t.name, t.description, t.allow_auto_assign, t.icon, t.icon_color, t.account_id,
       EXISTS (SELECT 1 FROM team_members tm WHERE tm.team_id = t.id AND tm.user_id = sqlc.arg(user_id)) AS is_member
FROM teams t WHERE t.account_id = sqlc.arg(account_id) ORDER BY t.id;
