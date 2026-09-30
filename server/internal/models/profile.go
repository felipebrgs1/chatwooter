package models

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/jackc/pgx/v5/pgtype"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
)

// Membership é o vínculo do usuário com uma conta (account_users) junto com os dados da conta.
type Membership struct {
	AccountID      int32
	AccountName    string
	AccountStatus  string
	OnboardingStep string
	ActiveAt       *time.Time
	Role           string // agent | administrator
	Availability   string // online | offline | busy
	AutoOffline    bool
	InviterID      *int32
}

// Permissions segue AccountUser#permissions do Chatwoot (sem papéis customizados, que são Enterprise).
func (m Membership) Permissions() []string { return []string{m.Role} }

func (m Membership) Administrator() bool { return m.Role == "administrator" }

// Profile é o usuário logado com suas contas, o que o dashboard precisa para começar.
type Profile struct {
	User            User
	AccessToken     string
	Memberships     []Membership
	ActiveAccountID *int32
}

func (u *Users) Profile(ctx context.Context, id int32) (Profile, error) {
	user, err := u.ByID(ctx, id)
	if err != nil {
		return Profile{}, err
	}
	token, err := u.q.GetUserAccessToken(ctx, pgtype.Int8{Int64: int64(id), Valid: true})
	if err != nil && !errors.Is(notFound(err), ErrNotFound) {
		return Profile{}, err
	}
	rows, err := u.q.ListMemberships(ctx, pgtype.Int8{Int64: int64(id), Valid: true})
	if err != nil {
		return Profile{}, err
	}

	p := Profile{User: user, AccessToken: token.String}
	for _, r := range rows {
		p.Memberships = append(p.Memberships, membershipFrom(r.AccountID, r.AccountName, r.AccountStatus,
			r.AccountCustomAttributes, r.ActiveAt, r.Role, r.Availability, r.AutoOffline, r.InviterID))
	}
	p.ActiveAccountID = mostRecentlyActive(p.Memberships)
	return p, nil
}

// MembershipFor devolve ErrNotFound quando o usuário não pertence à conta.
func (u *Users) MembershipFor(ctx context.Context, userID, accountID int32) (Membership, error) {
	r, err := u.q.GetMembership(ctx, sqlc.GetMembershipParams{
		UserID:    pgtype.Int8{Int64: int64(userID), Valid: true},
		AccountID: pgtype.Int8{Int64: int64(accountID), Valid: true},
	})
	if err != nil {
		return Membership{}, notFound(err)
	}
	return membershipFrom(r.AccountID, r.AccountName, r.AccountStatus, r.AccountCustomAttributes,
		r.ActiveAt, r.Role, r.Availability, r.AutoOffline, r.InviterID), nil
}

func membershipFrom(accountID pgtype.Int8, name string, status pgtype.Int4, custom []byte, activeAt *time.Time,
	role pgtype.Int4, availability int32, autoOffline bool, inviter pgtype.Int8,
) Membership {
	m := Membership{
		AccountID:      toInt32(accountID.Int64),
		AccountName:    name,
		AccountStatus:  accountStatus(status.Int32),
		OnboardingStep: onboardingStep(custom),
		ActiveAt:       activeAt,
		Role:           "agent",
		Availability:   availabilityName(availability),
		AutoOffline:    autoOffline,
	}
	if role.Valid && role.Int32 == 1 {
		m.Role = "administrator"
	}
	if inviter.Valid {
		id := toInt32(inviter.Int64)
		m.InviterID = &id
	}
	return m
}

func accountStatus(v int32) string {
	if v == 1 {
		return "suspended"
	}
	return "active"
}

func availabilityName(v int32) string {
	switch v {
	case 1:
		return "offline"
	case 2:
		return "busy"
	}
	return "online"
}

func onboardingStep(custom []byte) string {
	var attrs map[string]any
	if json.Unmarshal(custom, &attrs) != nil {
		return ""
	}
	step, _ := attrs["onboarding_step"].(string)
	return step
}

// mostRecentlyActive replica `max_by { [active_at ? 1 : 0, active_at] }` do jbuilder: contas com atividade
// vencem as sem; entre empates vale a primeira.
func mostRecentlyActive(ms []Membership) *int32 {
	var best *Membership
	for i := range ms {
		m := &ms[i]
		switch {
		case best == nil:
			best = m
		case m.ActiveAt != nil && (best.ActiveAt == nil || m.ActiveAt.After(*best.ActiveAt)):
			best = m
		}
	}
	if best == nil {
		return nil
	}
	id := best.AccountID
	return &id
}

// account_users guarda ids em bigint, mas todas as chaves referenciadas são integer (int32).
func toInt32(v int64) int32 { return int32(v) } //nolint:gosec // FKs para colunas integer
