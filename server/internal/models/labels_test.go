package models_test

import (
	"context"
	"testing"

	"github.com/felipeborgaco/chatwooter/server/internal/factory"
	"github.com/felipeborgaco/chatwooter/server/internal/models"
)

func TestLabelsListOnlyTheAccountsOrderedByTitle(t *testing.T) {
	pool, f := migratedPool(t)
	account, other := f.Account(), f.Account()
	desc := "clientes importantes"
	f.AccountLabel(account, func(l *factory.AccountLabel) { l.Title, l.Color, l.Description = "vip", "#00ff00", &desc })
	f.AccountLabel(account, func(l *factory.AccountLabel) { l.Title, l.ShowOnSidebar = "cobranca", false })
	f.AccountLabel(other, func(l *factory.AccountLabel) { l.Title = "alheia" })

	labels, err := models.NewLabels(pool).List(context.Background(), account.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(labels) != 2 || labels[0].Title != "cobranca" || labels[1].Title != "vip" {
		t.Fatalf("esperava [cobranca vip], veio %+v", labels)
	}
	vip := labels[1]
	if vip.Color != "#00ff00" || vip.Description == nil || *vip.Description != desc || !vip.ShowOnSidebar {
		t.Fatalf("campos da etiqueta: %+v", vip)
	}
	if labels[0].ShowOnSidebar || labels[0].Description != nil {
		t.Fatalf("show_on_sidebar/description: %+v", labels[0])
	}
}
