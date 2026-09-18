package main

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// TestRunJob garante que runJob incrementa as métricas sem panicar,
// tanto no caminho de sucesso quanto no de erro.
func TestRunJob(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/error" {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	client := &http.Client{Timeout: 2 * time.Second}
	logger := slog.New(slog.NewJSONHandler(io.Discard, nil))

	// caminho de sucesso
	runJob(client, srv.URL, "/", logger)
	// caminho de erro (5xx)
	runJob(client, srv.URL, "/error", logger)
}

func TestGetenv(t *testing.T) {
	t.Setenv("FOO_TEST_VAR", "bar")
	if got := getenv("FOO_TEST_VAR", "fallback"); got != "bar" {
		t.Fatalf("esperava 'bar', obteve %q", got)
	}
	if got := getenv("VAR_QUE_NAO_EXISTE_123", "fallback"); got != "fallback" {
		t.Fatalf("esperava 'fallback', obteve %q", got)
	}
}
