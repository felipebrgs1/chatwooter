package config_test

import (
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/config"
)

func TestLoadDefaults(t *testing.T) {
	cfg, err := config.Load(func(string) string { return "" })
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != "4000" {
		t.Errorf("Port = %q, want 4000", cfg.Port)
	}
	if cfg.DatabaseURL != "postgres://postgres:postgres@localhost:5432/chatwooter_dev?sslmode=disable" {
		t.Errorf("DatabaseURL = %q", cfg.DatabaseURL)
	}
}

func TestLoadFromEnv(t *testing.T) {
	env := map[string]string{
		"PORT":       "8080",
		"PGHOST":     "db",
		"PGUSER":     "u",
		"PGPASSWORD": "p",
		"PGDATABASE": "d",
	}
	cfg, err := config.Load(func(k string) string { return env[k] })
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != "8080" {
		t.Errorf("Port = %q", cfg.Port)
	}
	if want := "postgres://u:p@db:5432/d?sslmode=disable"; cfg.DatabaseURL != want {
		t.Errorf("DatabaseURL = %q, want %q", cfg.DatabaseURL, want)
	}
}

func TestDatabaseURLOverridesParts(t *testing.T) {
	env := map[string]string{"DATABASE_URL": "postgres://x/y", "PGHOST": "ignored"}
	cfg, err := config.Load(func(k string) string { return env[k] })
	if err != nil {
		t.Fatal(err)
	}
	if cfg.DatabaseURL != "postgres://x/y" {
		t.Errorf("DatabaseURL = %q", cfg.DatabaseURL)
	}
}

func TestLoadEncryptionKey(t *testing.T) {
	cfg, err := config.Load(func(k string) string {
		if k == "ENCRYPTION_KEY" {
			return "abc"
		}
		return ""
	})
	if err != nil || cfg.EncryptionKey != "abc" {
		t.Fatalf("EncryptionKey = %q, %v", cfg.EncryptionKey, err)
	}
}
