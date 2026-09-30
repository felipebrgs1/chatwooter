package views

import "github.com/felipeborgaco/chatwooter/server/internal/models"

// Teams é o index: um array puro, sem `payload` (teams/index.json.jbuilder).
func Teams(teams []models.Team) []TeamJSON {
	out := make([]TeamJSON, 0, len(teams))
	for _, t := range teams {
		out = append(out, Team(t))
	}
	return out
}
