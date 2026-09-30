package views

// AuthErrors é o formato de erro do devise_token_auth: {"success": false, "errors": [...]}.
func AuthErrors(messages ...string) map[string]any {
	return map[string]any{"success": false, "errors": messages}
}

// Errors é o erro de API sem sessão: {"errors": [...]}.
func Errors(messages ...string) map[string]any {
	return map[string]any{"errors": messages}
}

// Error é o erro de autorização do Chatwoot: {"error": "..."}.
func Error(message string) map[string]any {
	return map[string]any{"error": message}
}

func Success() map[string]any { return map[string]any{"success": true} }
