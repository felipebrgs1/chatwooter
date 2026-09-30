package models_test

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
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

func TestUpdateProfile(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	agent := f.User(f.Account())
	users := models.NewUsers(pool)

	name, display, signature := "Ana Souza", "Ana", "Att, Ana"
	err := users.UpdateProfile(ctx, agent.ID, models.ProfileUpdate{
		Name: &name, DisplayName: &display, MessageSignature: &signature,
		UISettings: json.RawMessage(`{"sidebar_width":240,"is_contact_sidebar_open":false}`),
	})
	if err != nil {
		t.Fatal(err)
	}
	p, _ := users.Profile(ctx, agent.ID)
	if p.User.Name != "Ana Souza" || p.User.DisplayName != "Ana" || p.User.MessageSignature != "Att, Ana" || p.User.AvailableName() != "Ana" {
		t.Errorf("user = %+v", p.User)
	}
	if string(p.User.UISettings) == "" || !strings.Contains(string(p.User.UISettings), `"sidebar_width"`) {
		t.Errorf("ui_settings = %s", p.User.UISettings)
	}

	// campos ausentes não mudam o que já existe
	if err := users.UpdateProfile(ctx, agent.ID, models.ProfileUpdate{DisplayName: ptr("")}); err != nil {
		t.Fatal(err)
	}
	p, _ = users.Profile(ctx, agent.ID)
	if p.User.Name != "Ana Souza" || p.User.AvailableName() != "Ana Souza" || p.User.MessageSignature != "Att, Ana" {
		t.Errorf("depois do parcial: %+v", p.User)
	}
	if err := users.UpdateProfile(ctx, agent.ID, models.ProfileUpdate{Name: ptr("  ")}); !errors.Is(err, models.ErrInvalid) {
		t.Errorf("nome vazio: err = %v", err)
	}
	if err := users.UpdateProfile(ctx, agent.ID, models.ProfileUpdate{UISettings: json.RawMessage(`[1,2]`)}); !errors.Is(err, models.ErrInvalid) {
		t.Errorf("ui_settings que não é objeto: err = %v", err)
	}
}

func ptr[T any](v T) *T { return &v }

func TestAvailabilityAutoOfflineAndActiveAccount(t *testing.T) {
	pool, f := migratedPool(t)
	ctx := context.Background()
	one, two := f.Account(), f.Account()
	agent := f.User(one)
	f.Member(two, agent, 0)
	users := models.NewUsers(pool)

	if err := users.SetAvailability(ctx, agent.ID, one.ID, "busy"); err != nil {
		t.Fatal(err)
	}
	if err := users.SetAutoOffline(ctx, agent.ID, one.ID, false); err != nil {
		t.Fatal(err)
	}
	m, _ := users.MembershipFor(ctx, agent.ID, one.ID)
	if m.Availability != "busy" || m.AutoOffline {
		t.Errorf("membership = %+v", m)
	}
	other, _ := users.MembershipFor(ctx, agent.ID, two.ID)
	if other.Availability != "online" {
		t.Error("a disponibilidade é por conta")
	}
	if err := users.SetAvailability(ctx, agent.ID, one.ID, "voando"); !errors.Is(err, models.ErrInvalid) {
		t.Errorf("valor inválido: %v", err)
	}
	if err := users.SetAvailability(ctx, agent.ID, f.Account().ID, "online"); !errors.Is(err, models.ErrNotFound) {
		t.Errorf("conta alheia: %v", err)
	}

	if err := users.SetActiveAccount(ctx, agent.ID, two.ID); err != nil {
		t.Fatal(err)
	}
	p, _ := users.Profile(ctx, agent.ID)
	if p.ActiveAccountID == nil || *p.ActiveAccountID != two.ID {
		t.Errorf("conta ativa = %v, want %d", p.ActiveAccountID, two.ID)
	}
	if err := users.SetActiveAccount(ctx, agent.ID, f.Account().ID); !errors.Is(err, models.ErrNotFound) {
		t.Errorf("conta alheia: %v", err)
	}
}
