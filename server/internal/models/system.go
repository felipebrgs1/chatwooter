// Package models concentra regras de negócio e acesso a dados. É a única camada que fala com o banco.
package models

import "context"

type Pinger interface {
	Ping(ctx context.Context) error
}

// System expõe o estado da infraestrutura de que o app depende.
type System struct {
	DB Pinger
}

func (s System) DatabaseUp(ctx context.Context) bool {
	return s.DB.Ping(ctx) == nil
}
