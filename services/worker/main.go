// Observability Lab — Worker (Go).
//
// Serviço em Go que gera carga sintética contra a API periodicamente
// (mantém os dashboards "vivos" sem intervenção manual) e expõe suas
// próprias métricas Prometheus em /metrics.
//
// Demonstra: Go idiomático, cliente HTTP com timeout, métricas Prometheus,
// logs estruturados (JSON), graceful shutdown e configuração via env.
package main

import (
	"context"
	"log/slog"
	"math/rand"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	jobsProcessed = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "worker_jobs_total",
			Help: "Total de jobs disparados pelo worker",
		},
		[]string{"target", "result"},
	)

	jobDuration = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "worker_job_duration_seconds",
		Help:    "Duração dos jobs do worker em segundos",
		Buckets: prometheus.DefBuckets,
	})
)

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	apiBase := getenv("API_BASE_URL", "http://api:8000")
	metricsAddr := getenv("METRICS_ADDR", ":9100")
	intervalSec, _ := strconv.Atoi(getenv("INTERVAL_SECONDS", "3"))

	client := &http.Client{Timeout: 5 * time.Second}
	endpoints := []string{"/work", "/error", "/"}

	// Servidor de métricas
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())
	srv := &http.Server{Addr: metricsAddr, Handler: mux}
	go func() {
		logger.Info("metrics_server_started", "addr", metricsAddr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("metrics_server_error", "error", err.Error())
		}
	}()

	// Loop de carga
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	ticker := time.NewTicker(time.Duration(intervalSec) * time.Second)
	defer ticker.Stop()

	logger.Info("worker_started", "api", apiBase, "interval_s", intervalSec)

	for {
		select {
		case <-ctx.Done():
			logger.Info("worker_shutting_down")
			shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			_ = srv.Shutdown(shutdownCtx)
			return
		case <-ticker.C:
			target := endpoints[rand.Intn(len(endpoints))]
			runJob(client, apiBase, target, logger)
		}
	}
}

func runJob(client *http.Client, base, target string, logger *slog.Logger) {
	start := time.Now()
	result := "success"

	resp, err := client.Get(base + target)
	if err != nil {
		result = "error"
		logger.Warn("job_failed", "target", target, "error", err.Error())
	} else {
		defer resp.Body.Close()
		if resp.StatusCode >= 500 {
			result = "error"
		}
		logger.Info("job_done", "target", target, "status", resp.StatusCode)
	}

	elapsed := time.Since(start).Seconds()
	jobDuration.Observe(elapsed)
	jobsProcessed.WithLabelValues(target, result).Inc()
}
