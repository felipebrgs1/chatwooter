package models

import (
	"bytes"
	"context"
	"crypto/md5" // #nosec G501 -- ActiveStorage uses MD5 as a file checksum, not for security.
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"os"
	"path/filepath"
	"regexp"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	_ "golang.org/x/image/webp"
)

// v1 uses local files with the existing ActiveStorage catalog. URLs remain account-authenticated;
// UPLOADS_DIR must point to a persistent volume when deployed (no schema changes or public bucket).
const AvatarMaxBytes = 5 * 1024 * 1024

var avatarKey = regexp.MustCompile(`\A[a-zA-Z0-9]{20,64}\z`)

type CompanyAvatarFile struct {
	Data        []byte
	ContentType string
}

func (c *Companies) avatarPath(key string) (string, error) {
	if !avatarKey.MatchString(key) {
		return "", ErrNotFound
	}
	return filepath.Join(c.uploadsDir, key), nil
}

func (c *Companies) avatarURL(ctx context.Context, accountID int32, id int64) (string, error) {
	blob, err := c.q.CompanyAvatar(ctx, sqlc.CompanyAvatarParams{AccountID: int64(accountID), ID: id})
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("/api/v1/accounts/%d/companies/%d/avatar?version=%s", accountID, id, blob.Key), nil
}

func (c *Companies) ReadAvatar(ctx context.Context, accountID int32, id int64) (CompanyAvatarFile, error) {
	blob, err := c.q.CompanyAvatar(ctx, sqlc.CompanyAvatarParams{AccountID: int64(accountID), ID: id})
	if err != nil {
		return CompanyAvatarFile{}, notFound(err)
	}
	path, err := c.avatarPath(blob.Key)
	if err != nil {
		return CompanyAvatarFile{}, err
	}
	data, err := os.ReadFile(path) // #nosec G304 -- avatarPath validates a single alphanumeric key within the configured directory.
	if errors.Is(err, os.ErrNotExist) {
		return CompanyAvatarFile{}, ErrNotFound
	}
	return CompanyAvatarFile{data, blob.ContentType.String}, err
}

func (c *Companies) UploadAvatar(ctx context.Context, accountID int32, id int64, filename string, data []byte) (Company, error) {
	invalid := &ValidationError{}
	config, format, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil || len(data) > AvatarMaxBytes || config.Width < 1 || config.Height < 1 || config.Width > 8192 || config.Height > 8192 {
		invalid.add("avatar", "Avatar must be a valid image smaller than 5 MB")
		return Company{}, invalid
	}
	mime := map[string]string{"png": "image/png", "jpeg": "image/jpeg", "gif": "image/gif", "webp": "image/webp"}[format]
	if mime == "" {
		invalid.add("avatar", "Avatar format is not supported")
		return Company{}, invalid
	}
	if _, err := c.Get(ctx, accountID, id); err != nil {
		return Company{}, err
	}
	keyBytes := make([]byte, 24)
	if _, err := rand.Read(keyBytes); err != nil {
		return Company{}, err
	}
	key := hex.EncodeToString(keyBytes)
	path, err := c.avatarPath(key)
	if err != nil {
		return Company{}, err
	}
	if err := os.MkdirAll(c.uploadsDir, 0o700); err != nil {
		return Company{}, err
	}
	if err := os.WriteFile(path, data, 0o600); err != nil {
		return Company{}, err
	}
	var old sqlc.ActiveStorageBlob
	var oldErr error
	checksum := md5.Sum(data) // #nosec G401 -- Match the ActiveStorage checksum format.
	err = withTx(ctx, c.db, func(tx pgx.Tx) error {
		q := sqlc.New(tx)
		if _, err := q.LockCompany(ctx, sqlc.LockCompanyParams{AccountID: int64(accountID), ID: id}); err != nil {
			return notFound(err)
		}
		old, oldErr = q.CompanyAvatar(ctx, sqlc.CompanyAvatarParams{AccountID: int64(accountID), ID: id})
		if oldErr != nil && !errors.Is(oldErr, pgx.ErrNoRows) {
			return oldErr
		}
		blobID, err := q.CreateAvatarBlob(ctx, sqlc.CreateAvatarBlobParams{Key: key, Filename: filepath.Base(filename), ContentType: pgtype.Text{String: mime, Valid: true}, ByteSize: int64(len(data)), Checksum: pgtype.Text{String: base64.StdEncoding.EncodeToString(checksum[:]), Valid: true}})
		if err != nil {
			return err
		}
		if err := q.DetachCompanyAvatar(ctx, id); err != nil {
			return err
		}
		if err := q.AttachCompanyAvatar(ctx, sqlc.AttachCompanyAvatarParams{RecordID: id, BlobID: blobID}); err != nil {
			return err
		}
		if oldErr == nil {
			return q.DeleteAvatarBlob(ctx, old.ID)
		}
		return nil
	})
	if err != nil {
		_ = os.Remove(path)
		return Company{}, err
	}
	if oldErr == nil {
		if previous, err := c.avatarPath(old.Key); err == nil {
			_ = os.Remove(previous)
		}
	}
	return c.Get(ctx, accountID, id)
}

func (c *Companies) DeleteAvatar(ctx context.Context, accountID int32, id int64) error {
	if _, err := c.Get(ctx, accountID, id); err != nil {
		return err
	}
	var old sqlc.ActiveStorageBlob
	var oldErr error
	err := withTx(ctx, c.db, func(tx pgx.Tx) error {
		q := sqlc.New(tx)
		if _, err := q.LockCompany(ctx, sqlc.LockCompanyParams{AccountID: int64(accountID), ID: id}); err != nil {
			return notFound(err)
		}
		old, oldErr = q.CompanyAvatar(ctx, sqlc.CompanyAvatarParams{AccountID: int64(accountID), ID: id})
		if oldErr != nil && !errors.Is(oldErr, pgx.ErrNoRows) {
			return oldErr
		}
		if err := q.DetachCompanyAvatar(ctx, id); err != nil {
			return err
		}
		if oldErr == nil {
			return q.DeleteAvatarBlob(ctx, old.ID)
		}
		return nil
	})
	if err == nil && oldErr == nil {
		if path, e := c.avatarPath(old.Key); e == nil {
			_ = os.Remove(path)
		}
	}
	return err
}
