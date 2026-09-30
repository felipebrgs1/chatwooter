package models_test

import (
	"context"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

func TestTeamsListMarksTheUsersMembership(t *testing.T) {
	pool, f := migratedPool(t)
	account, other := f.Account(), f.Account()
	user := f.User(account)
	sales := f.Team(account, func(tm *factory.Team) { tm.Name = "vendas" })
	f.Team(account, func(tm *factory.Team) { tm.Name = "suporte" })
	f.Team(other, func(tm *factory.Team) { tm.Name = "alheio" })
	f.TeamMember(sales, user)

	teams, err := models.NewTeams(pool).List(context.Background(), account.ID, user.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(teams) != 2 || teams[0].Name != "vendas" || teams[1].Name != "suporte" {
		t.Fatalf("esperava [vendas suporte] na ordem de criação, veio %+v", teams)
	}
	if !teams[0].IsMember || teams[1].IsMember {
		t.Fatalf("is_member: %+v", teams)
	}
	if teams[0].AccountID != account.ID || !teams[0].AllowAutoAssign {
		t.Fatalf("campos do time: %+v", teams[0])
	}
}
