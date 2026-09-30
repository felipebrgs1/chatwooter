package models

import "errors"

var (
	// ErrNotFound: o registro não existe (ou o token/sessão não vale mais).
	ErrNotFound = errors.New("não encontrado")
	// ErrInvalidCredentials não distingue e-mail inexistente de senha errada, de propósito.
	ErrInvalidCredentials = errors.New("credenciais inválidas")
)
