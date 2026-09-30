// Package views serializa as respostas JSON (equivalem aos jbuilder do Chatwoot).
package views

func Health(ok bool) map[string]string {
	if ok {
		return map[string]string{"status": "ok"}
	}
	return map[string]string{"status": "db_unavailable"}
}
