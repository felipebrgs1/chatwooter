package views

import (
	"encoding/json"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

// CustomFilterJSON espelha api/v1/models/_custom_filter.json.jbuilder.
type CustomFilterJSON struct {
	ID         int64           `json:"id"`
	Name       string          `json:"name"`
	FilterType string          `json:"filter_type"`
	Query      json.RawMessage `json:"query"`
	CreatedAt  string          `json:"created_at"`
	UpdatedAt  string          `json:"updated_at"`
}

func CustomFilter(f models.CustomFilter) CustomFilterJSON {
	return CustomFilterJSON{
		ID: f.ID, Name: f.Name, FilterType: f.FilterType, Query: f.Query,
		CreatedAt: railsTime(f.CreatedAt), UpdatedAt: railsTime(f.UpdatedAt),
	}
}

// CustomFilters espelha custom_filters/index.json.jbuilder (lista sem envelope).
func CustomFilters(list []models.CustomFilter) []CustomFilterJSON {
	out := make([]CustomFilterJSON, 0, len(list))
	for _, f := range list {
		out = append(out, CustomFilter(f))
	}
	return out
}
