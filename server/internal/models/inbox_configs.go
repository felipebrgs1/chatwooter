package models

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"

	"github.com/felipeborgaco/chatwooter/server/internal/db/sqlc"
	"github.com/felipeborgaco/chatwooter/server/internal/secrets"
)

// envelope é o que fica no jsonb: {"_enc": "v1:..."}. Linhas antigas guardam o mapa em texto claro.
const envelopeKey = "_enc"

// InboxConfigs guarda a configuração do adaptador de cada inbox (tokens do Telegram/WhatsApp),
// sempre cifrada em repouso.
type InboxConfigs struct {
	q   *sqlc.Queries
	box *secrets.Box
}

func NewInboxConfigs(db sqlc.DBTX, box *secrets.Box) *InboxConfigs {
	return &InboxConfigs{q: sqlc.New(db), box: box}
}

// Get devolve a configuração decifrada; inbox sem configuração devolve mapa vazio.
// Aceita linhas legadas em texto claro até EncryptLegacy rodar.
func (c *InboxConfigs) Get(ctx context.Context, inboxID int32) (map[string]any, error) {
	row, err := c.q.GetInboxConfig(ctx, inboxID)
	if errors.Is(err, pgx.ErrNoRows) {
		return map[string]any{}, nil
	}
	if err != nil {
		return nil, err
	}
	cfg, _, err := c.decode(row.ProviderConfig)
	return cfg, err
}

func (c *InboxConfigs) Put(ctx context.Context, inboxID int32, cfg map[string]any) error {
	plain, err := json.Marshal(cfg)
	if err != nil {
		return err
	}
	return c.store(ctx, inboxID, plain)
}

// EncryptLegacy cifra as linhas ainda em texto claro e devolve quantas migrou. É idempotente.
func (c *InboxConfigs) EncryptLegacy(ctx context.Context) (int, error) {
	rows, err := c.q.ListInboxConfigs(ctx)
	if err != nil {
		return 0, err
	}
	migrated := 0
	for _, row := range rows {
		cfg, sealed, err := c.decode(row.ProviderConfig)
		if err != nil {
			return migrated, fmt.Errorf("inbox %d: %w", row.InboxID, err)
		}
		if sealed || len(cfg) == 0 {
			continue
		}
		if err := c.Put(ctx, row.InboxID, cfg); err != nil {
			return migrated, fmt.Errorf("inbox %d: %w", row.InboxID, err)
		}
		migrated++
	}
	return migrated, nil
}

func (c *InboxConfigs) store(ctx context.Context, inboxID int32, plain []byte) error {
	body, err := json.Marshal(map[string]string{envelopeKey: c.box.Seal(plain)})
	if err != nil {
		return err
	}
	return c.q.UpsertInboxConfig(ctx, sqlc.UpsertInboxConfigParams{InboxID: inboxID, ProviderConfig: body})
}

func (c *InboxConfigs) decode(raw []byte) (cfg map[string]any, sealed bool, err error) {
	var generic map[string]any
	if err := json.Unmarshal(raw, &generic); err != nil {
		return nil, false, err
	}
	enc, ok := generic[envelopeKey].(string)
	if !ok {
		return generic, false, nil
	}
	plain, err := c.box.Open(enc)
	if err != nil {
		return nil, true, err
	}
	if err := json.Unmarshal(plain, &cfg); err != nil {
		return nil, true, err
	}
	return cfg, true, nil
}
