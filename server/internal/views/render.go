package views

import (
	"encoding/json"
	"net/http"
)

// JSON escreve o corpo já serializado pela view; é o único ponto que fala com http.ResponseWriter.
func JSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
