package models

import (
	"context"
	"math"
	"strings"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

type (
	CompanyContact struct {
		Contact Contact
		Company *Company
		Linked  bool
	}
	CompanyContactsPage struct {
		Contacts []CompanyContact
		Total    int64
	}
	CompanyNote struct {
		Note    Note
		Contact Contact
	}
)

func (c *Companies) Contact(ctx context.Context, accountID, contactID int32, companyID int64) (CompanyContact, error) {
	contact, err := NewContacts(c.db).Get(ctx, accountID, contactID, false)
	if err != nil {
		return CompanyContact{}, err
	}
	out := CompanyContact{Contact: contact, Linked: contact.CompanyID != nil && *contact.CompanyID == companyID}
	if contact.CompanyID != nil {
		company, err := c.Get(ctx, accountID, *contact.CompanyID)
		if err != nil {
			return out, err
		}
		out.Company = &company
	}
	return out, nil
}

func (c *Companies) Contacts(ctx context.Context, accountID int32, id int64, page int, search string, searching bool) (CompanyContactsPage, error) {
	if _, err := c.Get(ctx, accountID, id); err != nil {
		return CompanyContactsPage{}, err
	}
	if page < 1 || page > math.MaxInt32/15 {
		page = 1
	}
	cid := pgtype.Int8{Int64: id, Valid: true}
	total, err := c.q.CountCompanyContacts(ctx, sqlc.CountCompanyContactsParams{AccountID: accountID, CompanyID: cid, Searching: searching, Term: strings.TrimSpace(search)})
	if err != nil {
		return CompanyContactsPage{}, err
	}
	ids, err := c.q.ListCompanyContactIDs(ctx, sqlc.ListCompanyContactIDsParams{AccountID: accountID, CompanyID: cid, Searching: searching, Term: strings.TrimSpace(search), PageOffset: int32((page - 1) * 15)})
	out := CompanyContactsPage{Total: total, Contacts: []CompanyContact{}}
	if err != nil {
		return out, err
	}
	for _, contactID := range ids {
		contact, err := c.Contact(ctx, accountID, contactID, id)
		if err != nil {
			return out, err
		}
		out.Contacts = append(out.Contacts, contact)
	}
	return out, nil
}

// Membership is atomic across reassignment, cached names and both companies' counts.
func (c *Companies) Membership(ctx context.Context, accountID, contactID int32, id *int64, removeFrom *int64) error {
	return withTx(ctx, c.db, func(tx pgx.Tx) error {
		q := sqlc.New(tx)
		current, err := q.LockCompanyContact(ctx, sqlc.LockCompanyContactParams{AccountID: accountID, ID: contactID})
		if err != nil {
			return notFound(err)
		}
		if removeFrom != nil && (!current.CompanyID.Valid || current.CompanyID.Int64 != *removeFrom) {
			return ErrNotFound
		}
		var name pgtype.Text
		var companyID pgtype.Int8
		if id != nil {
			company, err := q.GetCompany(ctx, sqlc.GetCompanyParams{AccountID: int64(accountID), ID: *id})
			if err != nil {
				return notFound(err)
			}
			companyID = pgtype.Int8{Int64: *id, Valid: true}
			name = pgtype.Text{String: company.Name, Valid: true}
		}
		if err := q.AssignContactCompany(ctx, sqlc.AssignContactCompanyParams{AccountID: accountID, ID: contactID, CompanyID: companyID, CompanyName: name}); err != nil {
			return err
		}
		if current.CompanyID.Valid {
			if err := q.RefreshCompanyContactCount(ctx, sqlc.RefreshCompanyContactCountParams{AccountID: accountID, ID: current.CompanyID.Int64}); err != nil {
				return err
			}
		}
		if id != nil {
			return q.RefreshCompanyContactCount(ctx, sqlc.RefreshCompanyContactCountParams{AccountID: accountID, ID: *id, Activity: current.LastActivityAt})
		}
		return nil
	})
}

func (c *Companies) Conversations(ctx context.Context, accountID, userID int32, id int64, isAdmin bool) ([]ConversationItem, error) {
	if _, err := c.Get(ctx, accountID, id); err != nil {
		return nil, err
	}
	ids, err := c.q.CompanyConversationIDs(ctx, sqlc.CompanyConversationIDsParams{AccountID: accountID, UserID: userID, CompanyID: pgtype.Int8{Int64: id, Valid: true}, IsAdmin: isAdmin})
	if err != nil {
		return nil, err
	}
	out := []ConversationItem{}
	for _, displayID := range ids {
		item, err := NewConversations(c.db).Get(ctx, accountID, displayID)
		if err != nil {
			return nil, err
		}
		out = append(out, item)
	}
	return out, nil
}

func (c *Companies) Notes(ctx context.Context, accountID int32, id int64) ([]CompanyNote, error) {
	if _, err := c.Get(ctx, accountID, id); err != nil {
		return nil, err
	}
	ids, err := c.q.CompanyNoteIDs(ctx, sqlc.CompanyNoteIDsParams{AccountID: int64(accountID), CompanyID: pgtype.Int8{Int64: id, Valid: true}})
	if err != nil {
		return nil, err
	}
	out := []CompanyNote{}
	for _, row := range ids {
		note, err := NewContactNotes(c.db).Get(ctx, accountID, row.ContactID, row.ID)
		if err != nil {
			return nil, err
		}
		contact, err := NewContacts(c.db).Get(ctx, accountID, row.ContactID, false)
		if err != nil {
			return nil, err
		}
		out = append(out, CompanyNote{note, contact})
	}
	return out, nil
}
