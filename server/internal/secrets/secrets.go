// Package secrets cifra segredos em repouso (tokens de canal) com AES-256-GCM.
package secrets

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"
)

const prefix = "v1:"

type Box struct{ aead cipher.AEAD }

// ParseKey lê a chave de 32 bytes em base64 (ex.: `openssl rand -base64 32`).
func ParseKey(encoded string) ([]byte, error) {
	key, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return nil, fmt.Errorf("ENCRYPTION_KEY não é base64: %w", err)
	}
	if len(key) != 32 {
		return nil, fmt.Errorf("ENCRYPTION_KEY precisa ter 32 bytes, tem %d", len(key))
	}
	return key, nil
}

func NewBox(key []byte) (*Box, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	return &Box{aead: aead}, nil
}

// IsSealed diz se o texto tem o formato produzido por Seal.
func IsSealed(s string) bool { return strings.HasPrefix(s, prefix) }

// Seal devolve "v1:" + base64(nonce || texto cifrado). O nonce é novo a cada chamada.
func (b *Box) Seal(plaintext []byte) string {
	nonce := make([]byte, b.aead.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		panic(fmt.Errorf("sem entropia: %w", err)) // crypto/rand só falha se o SO estiver quebrado
	}
	return prefix + base64.StdEncoding.EncodeToString(b.aead.Seal(nonce, nonce, plaintext, nil))
}

func (b *Box) Open(sealed string) ([]byte, error) {
	if !IsSealed(sealed) {
		return nil, errors.New("valor não está cifrado")
	}
	raw, err := base64.StdEncoding.DecodeString(strings.TrimPrefix(sealed, prefix))
	if err != nil {
		return nil, fmt.Errorf("base64 inválido: %w", err)
	}
	n := b.aead.NonceSize()
	if len(raw) < n+b.aead.Overhead() {
		return nil, errors.New("valor cifrado curto demais")
	}
	plain, err := b.aead.Open(nil, raw[:n], raw[n:], nil)
	if err != nil {
		return nil, errors.New("não foi possível decifrar (chave errada ou dado adulterado)")
	}
	return plain, nil
}
