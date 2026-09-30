package views

import "time"

// railsTime é o formato que o ActiveSupport usa em JSON: milissegundos e Z.
func railsTime(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }

func railsTimePtr(t *time.Time) *string {
	if t == nil {
		return nil
	}
	s := railsTime(*t)
	return &s
}

func nilIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
