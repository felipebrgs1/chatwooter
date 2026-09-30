package models_test

import (
	"context"
	"testing"
	"time"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

func TestProfileListsMembershipsAndPicksMostRecentlyActiveAccount(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	older, newer := f.Account(), f.Account()
	agent := f.User(older, func(u *factory.User) { u.Name = "Ana"; u.Role = 1 })
	f.Member(newer, agent, 0)

	if _, err := pool.Exec(ctx, `UPDATE account_users SET active_at = $1 WHERE account_id = $2`,
		time.Now().UTC().Add(-time.Hour), older.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `UPDATE account_users SET active_at = $1 WHERE account_id = $2`,
		time.Now().UTC(), newer.ID); err != nil {
		t.Fatal(err)
	}

	p, err := models.NewUsers(pool).Profile(ctx, agent.ID)
	if err != nil {
		t.Fatal(err)
	}
	if p.User.Name != "Ana" || p.AccessToken != agent.AccessToken {
		t.Errorf("perfil = %+v", p)
	}
	if len(p.Memberships) != 2 {
		t.Fatalf("memberships = %d", len(p.Memberships))
	}
	if p.ActiveAccountID == nil || *p.ActiveAccountID != newer.ID {
		t.Errorf("conta ativa = %v, want %d", p.ActiveAccountID, newer.ID)
	}
	roles := map[int32]string{}
	for _, m := range p.Memberships {
		roles[m.AccountID] = m.Role
	}
	if roles[older.ID] != "administrator" || roles[newer.ID] != "agent" {
		t.Errorf("papéis = %v", roles)
	}
}

func TestProfileWithoutActivityFallsBackToAnyMembership(t *testing.T) {
	pool, f := migratedPool(t)
	account := f.Account()
	agent := f.User(account)
	p, err := models.NewUsers(pool).Profile(context.Background(), agent.ID)
	if err != nil {
		t.Fatal(err)
	}
	if p.ActiveAccountID == nil || *p.ActiveAccountID != account.ID {
		t.Errorf("conta ativa = %v", p.ActiveAccountID)
	}
}

func TestMembershipFor(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	mine, other := f.Account(), f.Account()
	agent := f.User(mine, func(u *factory.User) { u.Role = 1 })
	users := models.NewUsers(pool)

	m, err := users.MembershipFor(ctx, agent.ID, mine.ID)
	if err != nil || m.Role != "administrator" || m.AccountName != mine.Name {
		t.Fatalf("MembershipFor = %+v, %v", m, err)
	}
	if _, err := users.MembershipFor(ctx, agent.ID, other.ID); err == nil {
		t.Error("usuário de fora da conta deveria dar ErrNotFound")
	}
}

func TestAccountByID(t *testing.T) {
	pool, f := migratedPool(t)
	account := f.Account()
	got, err := models.NewAccounts(pool).ByID(context.Background(), account.ID)
	if err != nil || got.Name != account.Name || got.Status != "active" {
		t.Fatalf("ByID = %+v, %v", got, err)
	}
}
