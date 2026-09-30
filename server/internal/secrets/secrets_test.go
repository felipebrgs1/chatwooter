package secrets_test

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"strings"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/secrets"
)

func newBox(t *testing.T) *secrets.Box {
	t.Helper()
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		t.Fatal(err)
	}
	box, err := secrets.NewBox(key)
	if err != nil {
		t.Fatal(err)
	}
	return box
}

func TestSealOpenRoundTrip(t *testing.T) {
	box := newBox(t)
	plain := []byte(`{"bot_token":"123:abc"}`)

	sealed := box.Seal(plain)
	if strings.Contains(sealed, "123:abc") {
		t.Fatal("texto claro vazou no resultado")
	}
	if !secrets.IsSealed(sealed) {
		t.Fatalf("IsSealed(%q) = false", sealed)
	}
	got, err := box.Open(sealed)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, plain) {
		t.Errorf("Open = %q", got)
	}
}

func TestSealIsRandomized(t *testing.T) {
	box := newBox(t)
	first, second := box.Seal([]byte("x")), box.Seal([]byte("x"))
	if first == second {
		t.Fatal("dois Seal iguais: nonce não é aleatório")
	}
}

func TestOpenRejectsTamperedAndForeignData(t *testing.T) {
	box := newBox(t)
	sealed := box.Seal([]byte("segredo"))

	raw, _ := base64.StdEncoding.DecodeString(strings.TrimPrefix(sealed, "v1:"))
	raw[len(raw)-1] ^= 0xff
	tampered := "v1:" + base64.StdEncoding.EncodeToString(raw)
	if _, err := box.Open(tampered); err == nil {
		t.Error("dado adulterado deveria falhar")
	}
	if _, err := newBox(t).Open(sealed); err == nil {
		t.Error("outra chave deveria falhar")
	}
	for _, bad := range []string{"", "v1:", "v1:!!!", "texto-claro", "v1:" + base64.StdEncoding.EncodeToString([]byte("curto"))} {
		if _, err := box.Open(bad); err == nil {
			t.Errorf("Open(%q) deveria falhar", bad)
		}
	}
}

func TestParseKey(t *testing.T) {
	good := base64.StdEncoding.EncodeToString(make([]byte, 32))
	if _, err := secrets.ParseKey(good); err != nil {
		t.Errorf("chave válida: %v", err)
	}
	for _, bad := range []string{"", "não-é-base64", base64.StdEncoding.EncodeToString(make([]byte, 16))} {
		if _, err := secrets.ParseKey(bad); err == nil {
			t.Errorf("ParseKey(%q) deveria falhar", bad)
		}
	}
}
