// Package app liga config, banco, jobs e HTTP e expõe os comandos do binário: serve, migrate, seed e
// encrypt-provider-configs. O main só repassa os argumentos.
package app

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"

	"github.com/felipeborgaco/chatwooter/server/internal/config"
	"github.com/felipeborgaco/chatwooter/server/internal/db"
	"github.com/felipeborgaco/chatwooter/server/internal/jobs"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/router"
	"github.com/felipeborgaco/chatwooter/server/internal/secrets"
)

// Run executa o comando (o primeiro argumento; sem argumentos, serve).
func Run(ctx context.Context, args []string, getenv func(string) string, out io.Writer) error {
	cmd := "serve"
	if len(args) > 0 {
		cmd = args[0]
	}
	cfg, err := config.Load(getenv)
	if err != nil {
		return err
	}
	switch cmd {
	case "serve":
		return serve(ctx, cfg, out)
	case "migrate":
		return withPool(ctx, cfg, func(pool *pgxpool.Pool) error {
			if err := db.Migrate(ctx, pool); err != nil {
				return err
			}
			_, err := fmt.Fprintln(out, "migrations aplicadas")
			return err
		})
	case "seed":
		return withPool(ctx, cfg, func(pool *pgxpool.Pool) error {
			if err := models.SeedDev(ctx, pool); err != nil {
				return err
			}
			_, err := fmt.Fprintf(out, "seed ok: %s / %s (admin da conta Acme Inc)\n", models.DevSeedEmail, models.DevSeedPassword)
			return err
		})
	case "encrypt-provider-configs":
		return encryptProviderConfigs(ctx, cfg, out)
	}
	return fmt.Errorf("comando desconhecido %q (use serve, migrate, seed ou encrypt-provider-configs)", cmd)
}

func withPool(ctx context.Context, cfg config.Config, fn func(*pgxpool.Pool) error) error {
	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer pool.Close()
	return fn(pool)
}

func newBox(cfg config.Config) (*secrets.Box, error) {
	key, err := secrets.ParseKey(cfg.EncryptionKey)
	if err != nil {
		return nil, err
	}
	return secrets.NewBox(key)
}

func encryptProviderConfigs(ctx context.Context, cfg config.Config, out io.Writer) error {
	box, err := newBox(cfg)
	if err != nil {
		return err
	}
	return withPool(ctx, cfg, func(pool *pgxpool.Pool) error {
		n, err := models.NewInboxConfigs(pool, box).EncryptLegacy(ctx)
		if err != nil {
			return err
		}
		_, err = fmt.Fprintf(out, "%d configurações cifradas\n", n)
		return err
	})
}

const sessionTTL = 30 * 24 * time.Hour

// purgeExpiredSessions roda na partida e de hora em hora até o processo parar.
func purgeExpiredSessions(ctx context.Context, sessions *models.Sessions, log *slog.Logger) {
	tick := time.NewTicker(time.Hour)
	defer tick.Stop()
	for {
		if n, err := sessions.PurgeExpired(ctx); err != nil && ctx.Err() == nil {
			log.Error("purge de sessões falhou", "err", err)
		} else if n > 0 {
			log.Info("sessões expiradas removidas", "count", n)
		}
		select {
		case <-ctx.Done():
			return
		case <-tick.C:
		}
	}
}

func serve(ctx context.Context, cfg config.Config, out io.Writer) error {
	if _, err := newBox(cfg); err != nil {
		return err
	}
	log := slog.New(slog.NewJSONHandler(out, nil))

	return withPool(ctx, cfg, func(pool *pgxpool.Pool) error {
		var queue *river.Client[pgx.Tx]
		if workers, n := jobs.Workers(); n > 0 {
			var err error
			if queue, err = jobs.NewClient(pool, workers); err != nil {
				return err
			}
			if err = queue.Start(ctx); err != nil {
				return err
			}
		} else {
			log.Info("nenhum worker registrado: fila não iniciada")
		}

		sessions := models.NewSessions(pool, sessionTTL)
		go purgeExpiredSessions(ctx, sessions, log)

		srv := &http.Server{
			Addr: ":" + cfg.Port,
			Handler: router.New(router.Deps{
				System:        models.System{DB: pool},
				Users:         models.NewUsers(pool),
				Sessions:      sessions,
				Accounts:      models.NewAccounts(pool),
				Conversations: models.NewConversations(pool),
				Labels:        models.NewLabels(pool),
				Teams:         models.NewTeams(pool),
				Inboxes:       models.NewInboxes(pool),
				Contacts:      models.NewContacts(pool),
				ContactNotes:  models.NewContactNotes(pool),
				Companies:     models.NewCompanies(pool, cfg.UploadsDir),
				CustomFilters: models.NewCustomFilters(pool),
				Agents:        models.NewAgents(pool),
				SessionTTL:    sessionTTL,
				CookieSecure:  cfg.CookieSecure,
			}),
			ReadHeaderTimeout: 10 * time.Second,
		}
		go func() {
			<-ctx.Done()
			shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			_ = srv.Shutdown(shutdown)
		}()

		log.Info("listening", "port", cfg.Port)
		err := srv.ListenAndServe()

		if queue != nil {
			stop, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			if stopErr := queue.Stop(stop); stopErr != nil && err == nil {
				err = stopErr
			}
		}
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	})
}
