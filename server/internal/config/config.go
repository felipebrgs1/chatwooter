// Package config lê a configuração do processo a partir de variáveis de ambiente.
package config

import (
	"fmt"
	"net/url"
)

type Config struct {
	Port        string
	DatabaseURL string
	// EncryptionKey é a chave AES-256 (base64) dos segredos em repouso; validada por quem a usa.
	EncryptionKey string
	// CookieSecure marca o cookie de sessão como Secure (obrigatório atrás de HTTPS, ou seja, em produção).
	CookieSecure bool
}

// Load recebe getenv para os testes não dependerem do ambiente real.
func Load(getenv func(string) string) (Config, error) {
	return Config{
		Port:          or(getenv("PORT"), "4000"),
		DatabaseURL:   databaseURL(getenv),
		EncryptionKey: getenv("ENCRYPTION_KEY"),
		CookieSecure:  getenv("COOKIE_SECURE") == "true",
	}, nil
}

// DATABASE_URL vence; senão montamos a partir das mesmas PG* que o compose já usa.
func databaseURL(getenv func(string) string) string {
	if u := getenv("DATABASE_URL"); u != "" {
		return u
	}
	u := url.URL{
		Scheme:   "postgres",
		User:     url.UserPassword(or(getenv("PGUSER"), "postgres"), or(getenv("PGPASSWORD"), "postgres")),
		Host:     fmt.Sprintf("%s:%s", or(getenv("PGHOST"), "localhost"), or(getenv("PGPORT"), "5432")),
		Path:     or(getenv("PGDATABASE"), "chatwooter_dev"),
		RawQuery: "sslmode=disable",
	}
	return u.String()
}

func or(v, fallback string) string {
	if v == "" {
		return fallback
	}
	return v
}
