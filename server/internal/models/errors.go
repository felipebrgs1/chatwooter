package models

import "errors"

var (
	// ErrNotFound: o registro não existe (ou o token/sessão não vale mais).
	ErrNotFound = errors.New("não encontrado")
	// ErrInvalid: o pedido é bem formado, mas os dados não valem (status desconhecido, agente de outra conta...).
	ErrInvalid = errors.New("dados inválidos")
	// ErrInvalidCredentials não distingue e-mail inexistente de senha errada, de propósito.
	ErrInvalidCredentials = errors.New("credenciais inválidas")
)
