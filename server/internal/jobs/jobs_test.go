package jobs_test

import (
	"context"
	"testing"
	"time"

	"github.com/riverqueue/river"

	"github.com/felipeborgaco/chatwooter/server/internal/db"
	"github.com/felipeborgaco/chatwooter/server/internal/jobs"
	"github.com/felipeborgaco/chatwooter/server/internal/testdb"
)

type probeArgs struct{}

func (probeArgs) Kind() string { return "probe" }

type probeWorker struct {
	river.WorkerDefaults[probeArgs]
	done chan<- struct{}
}

func (w *probeWorker) Work(context.Context, *river.Job[probeArgs]) error {
	w.done <- struct{}{}
	return nil
}

func TestClientRunsJobsOnEveryQueue(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatal(err)
	}

	done := make(chan struct{}, len(jobs.Queues))
	workers := river.NewWorkers()
	river.AddWorker(workers, &probeWorker{done: done})

	client, err := jobs.NewClient(pool, workers)
	if err != nil {
		t.Fatal(err)
	}
	if err := client.Start(ctx); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = client.Stop(ctx) })

	for queue := range jobs.Queues {
		if _, err := client.Insert(ctx, probeArgs{}, &river.InsertOpts{Queue: queue}); err != nil {
			t.Fatal(err)
		}
	}
	for range jobs.Queues {
		select {
		case <-done:
		case <-time.After(10 * time.Second):
			t.Fatal("job não foi executado em alguma fila")
		}
	}
}
