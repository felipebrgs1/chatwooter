package controllers

import (
	"io/fs"
	"net/http"
	"os"
	"path"
	"strings"
)

// Web serve o build do dashboard (web/dist). Rotas do TanStack Router não existem como arquivo: caem no
// index.html, menos /assets (asset ausente é erro de deploy) e as rotas de API, que seguem 404.
type Web struct {
	Dir string
}

func (c Web) Serve(w http.ResponseWriter, r *http.Request) {
	clean := path.Clean("/" + r.URL.Path)
	if strings.HasPrefix(clean, "/api/") || strings.HasPrefix(clean, "/auth/") || clean == "/cable" {
		http.NotFound(w, r)
		return
	}
	// os.DirFS recusa nomes fora do diretório, então nenhum caminho da URL escapa do build.
	files := os.DirFS(c.Dir)
	if clean != "/" {
		name := strings.TrimPrefix(clean, "/")
		if info, err := fs.Stat(files, name); err == nil && !info.IsDir() {
			// O Vite põe hash no nome de tudo em /assets.
			if strings.HasPrefix(clean, "/assets/") {
				w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
			}
			http.ServeFileFS(w, r, files, name) //nolint:gosec // os.DirFS confina o nome ao build
			return
		}
		if strings.HasPrefix(clean, "/assets/") {
			http.NotFound(w, r)
			return
		}
	}
	// Sem cache: um deploy novo troca os nomes dos assets que o index.html referencia.
	w.Header().Set("Cache-Control", "no-cache")
	http.ServeFileFS(w, r, files, "index.html")
}
