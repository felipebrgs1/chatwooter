package models

import (
	"context"
	"errors"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
)

// Labelable do Chatwoot (acts_as_taggable_on :labels) sobre tags + taggings, contexto 'labels', para contatos e
// conversas. O Chatwoot desliga o contador (tags_counter = false) e não diferencia maiúsculas (strict_case_match = false).

// labelsOf é o label_list, na ordem das taggings.
func labelsOf(ctx context.Context, db sqlc.DBTX, taggableType string, id int32) ([]string, error) {
	rows, err := db.Query(ctx, `SELECT t.name FROM taggings tg JOIN tags t ON t.id = tg.tag_id
		WHERE tg.taggable_type = $1 AND tg.taggable_id = $2 AND tg.context = 'labels' ORDER BY tg.id`, taggableType, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		out = append(out, name)
	}
	return out, rows.Err()
}

// cleanTagList é o DefaultParser + TagList#clean!: junta, separa por vírgula, apara, tira vazios e
// repetidos (sem distinguir maiúsculas). As aspas que o parser do gem aceita não são tratadas.
func cleanTagList(labels []string) []string {
	out := []string{}
	seen := map[string]bool{}
	for _, raw := range strings.Split(strings.Join(labels, ","), ",") {
		name := strings.TrimSpace(raw)
		if name == "" || seen[strings.ToLower(name)] {
			continue
		}
		seen[strings.ToLower(name)] = true
		out = append(out, name)
	}
	return out
}

// setLabels é o update_labels: substitui as etiquetas (mantém as taggings que continuam, apaga as que saíram,
// cria as novas reaproveitando a tag de mesmo nome) e devolve a lista pedida já limpa, como o label_list em
// memória. Roda dentro da transação de quem chama.
func setLabels(ctx context.Context, tx pgx.Tx, taggableType string, id int32, labels []string) ([]string, error) {
	list := cleanTagList(labels)
	if _, err := tx.Exec(ctx, `DELETE FROM taggings tg USING tags t WHERE t.id = tg.tag_id AND tg.taggable_type = $1
		AND tg.taggable_id = $2 AND tg.context = 'labels' AND lower(t.name) <> ALL (SELECT lower(l) FROM unnest($3::text[]) l)`,
		taggableType, id, list); err != nil {
		return nil, err
	}
	for _, name := range list {
		var tagID int32
		err := tx.QueryRow(ctx, `SELECT id FROM tags WHERE lower(name) = lower($1) ORDER BY id LIMIT 1`, name).Scan(&tagID)
		if errors.Is(err, pgx.ErrNoRows) {
			if err := tx.QueryRow(ctx, `INSERT INTO tags (name) VALUES ($1) RETURNING id`, name).Scan(&tagID); err != nil {
				return nil, err
			}
		} else if err != nil {
			return nil, err
		}
		if _, err := tx.Exec(ctx, `INSERT INTO taggings (tag_id, taggable_type, taggable_id, context, created_at)
			SELECT $1, $2::varchar, $3, 'labels', now() WHERE NOT EXISTS (SELECT 1 FROM taggings
				WHERE tag_id = $1 AND taggable_type = $2::varchar AND taggable_id = $3 AND context = 'labels')`, tagID, taggableType, id); err != nil {
			return nil, err
		}
	}
	return list, nil
}
