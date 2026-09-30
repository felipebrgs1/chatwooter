package controllers

import (
	"io"
	"net/http"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

func (c Companies) UploadAvatar(w http.ResponseWriter, r *http.Request) {
	id, ok := c.companyID(w, r)
	if !ok {
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, models.AvatarMaxBytes+1024*1024)
	if err := r.ParseMultipartForm(models.AvatarMaxBytes); err != nil { // #nosec G120 -- MaxBytesReader above caps the entire request to 6 MB.
		views.JSON(w, 422, views.Error("Avatar is too large or invalid"))
		return
	}
	defer func() { _ = r.MultipartForm.RemoveAll() }()
	file, header, err := r.FormFile("company[avatar]")
	if err != nil {
		views.JSON(w, 400, views.Error("Avatar is required"))
		return
	}
	defer func() { _ = file.Close() }()
	data, err := io.ReadAll(io.LimitReader(file, models.AvatarMaxBytes+1))
	if err != nil {
		serverError(w, err)
		return
	}
	company, err := c.Companies.UploadAvatar(r.Context(), CurrentMembership(r).AccountID, id, header.Filename, data)
	if err != nil {
		contactError(w, err)
		return
	}
	views.JSON(w, 200, views.CompanyShow(company))
}

func (c Companies) Avatar(w http.ResponseWriter, r *http.Request) {
	id, ok := c.companyID(w, r)
	if !ok {
		return
	}
	file, err := c.Companies.ReadAvatar(r.Context(), CurrentMembership(r).AccountID, id)
	if err != nil {
		modelError(w, err)
		return
	}
	w.Header().Set("Content-Type", file.ContentType)
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Cache-Control", "private, no-cache")
	_, _ = w.Write(file.Data)
}

func (c Companies) DeleteAvatar(w http.ResponseWriter, r *http.Request) {
	id, ok := c.companyID(w, r)
	if !ok {
		return
	}
	if err := c.Companies.DeleteAvatar(r.Context(), CurrentMembership(r).AccountID, id); err != nil {
		modelError(w, err)
		return
	}
	w.WriteHeader(200)
}
