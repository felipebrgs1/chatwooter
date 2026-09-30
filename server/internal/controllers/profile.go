package controllers

import (
	"encoding/json"
	"net/http"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

type Profile struct {
	Users *models.Users
}

func (c Profile) Show(w http.ResponseWriter, r *http.Request) {
	c.render(w, r)
}

func (c Profile) render(w http.ResponseWriter, r *http.Request) {
	p, err := c.Users.Profile(r.Context(), CurrentUser(r).ID)
	if err != nil {
		serverError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.Profile(p))
}

// Update é PUT /api/v1/profile ({"profile": {...}}).
func (c Profile) Update(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Profile struct {
			Name             *string         `json:"name"`
			DisplayName      *string         `json:"display_name"`
			MessageSignature *string         `json:"message_signature"`
			UISettings       json.RawMessage `json:"ui_settings"`
		} `json:"profile"`
	}
	if !decode(w, r, &in) {
		return
	}
	p := in.Profile
	err := c.Users.UpdateProfile(r.Context(), CurrentUser(r).ID, models.ProfileUpdate{
		Name: p.Name, DisplayName: p.DisplayName, MessageSignature: p.MessageSignature, UISettings: p.UISettings,
	})
	if err != nil {
		modelError(w, err)
		return
	}
	c.render(w, r)
}

type accountParams struct {
	Profile struct {
		AccountID    int32  `json:"account_id"`
		Availability string `json:"availability"`
		AutoOffline  *bool  `json:"auto_offline"`
	} `json:"profile"`
}

func (c Profile) Availability(w http.ResponseWriter, r *http.Request) {
	var in accountParams
	if !decode(w, r, &in) {
		return
	}
	if err := c.Users.SetAvailability(r.Context(), CurrentUser(r).ID, in.Profile.AccountID, in.Profile.Availability); err != nil {
		modelError(w, err)
		return
	}
	c.render(w, r)
}

func (c Profile) AutoOffline(w http.ResponseWriter, r *http.Request) {
	var in accountParams
	if !decode(w, r, &in) {
		return
	}
	// Chatwoot: `auto_offline || false`
	auto := in.Profile.AutoOffline != nil && *in.Profile.AutoOffline
	if err := c.Users.SetAutoOffline(r.Context(), CurrentUser(r).ID, in.Profile.AccountID, auto); err != nil {
		modelError(w, err)
		return
	}
	c.render(w, r)
}

func (c Profile) SetActiveAccount(w http.ResponseWriter, r *http.Request) {
	var in accountParams
	if !decode(w, r, &in) {
		return
	}
	if err := c.Users.SetActiveAccount(r.Context(), CurrentUser(r).ID, in.Profile.AccountID); err != nil {
		modelError(w, err)
		return
	}
	w.WriteHeader(http.StatusOK)
}
