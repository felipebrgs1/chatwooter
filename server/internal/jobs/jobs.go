// Package jobs configura o River (fila de jobs em Postgres), substituto do Oban.
// Efeitos colaterais com o mundo externo (Telegram, Meta, webhooks de saída) só rodam por aqui.
package jobs

import (
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
)

const (
	QueueWebhookIngest    = "webhook_ingest"
	QueueSenders          = "senders"
	QueueOutgoingWebhooks = "outgoing_webhooks"
	QueueNotifications    = "notifications"
	QueueMaintenance      = "maintenance"
	QueueImport           = "import"
)

// Workers devolve o conjunto de workers do app e quantos são. Cada worker novo (Telegram, WhatsApp,
// webhooks de saída...) é registrado aqui. O River recusa subir sem nenhum.
func Workers() (*river.Workers, int) {
	workers := river.NewWorkers()
	return workers, 0
}

// Queues lista todas as filas e quantos jobs cada uma executa em paralelo.
var Queues = map[string]int{
	QueueWebhookIngest:    20,
	QueueSenders:          20,
	QueueOutgoingWebhooks: 10,
	QueueNotifications:    10,
	QueueMaintenance:      2,
	QueueImport:           2,
}

func NewClient(pool *pgxpool.Pool, workers *river.Workers) (*river.Client[pgx.Tx], error) {
	return river.NewClient(riverpgxv5.New(pool), &river.Config{
		Queues:  queueConfigs(),
		Workers: workers,
	})
}

func queueConfigs() map[string]river.QueueConfig {
	out := make(map[string]river.QueueConfig, len(Queues))
	for name, workers := range Queues {
		out[name] = river.QueueConfig{MaxWorkers: workers}
	}
	return out
}
