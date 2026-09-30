package views

import "github.com/felipeborgaco/chatwooter/server/internal/models"

// LabelJSON espelha api/v1/accounts/labels/index.json.jbuilder.
type LabelJSON struct {
	ID            int64   `json:"id"`
	Title         string  `json:"title"`
	Description   *string `json:"description"`
	Color         string  `json:"color"`
	ShowOnSidebar bool    `json:"show_on_sidebar"`
}

func Labels(labels []models.Label) map[string][]LabelJSON {
	out := make([]LabelJSON, 0, len(labels))
	for _, l := range labels {
		out = append(out, LabelJSON{
			ID: l.ID, Title: l.Title, Description: l.Description, Color: l.Color, ShowOnSidebar: l.ShowOnSidebar,
		})
	}
	return map[string][]LabelJSON{"payload": out}
}
