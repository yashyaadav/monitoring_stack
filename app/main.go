package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	version = "dev"
	commit  = "unknown"
)

func instrument(route string, h http.HandlerFunc) http.Handler {
	labels := prometheus.Labels{"route": route}
	return promhttp.InstrumentHandlerInFlight(httpInFlightRequests,
		promhttp.InstrumentHandlerDuration(httpRequestDuration.MustCurryWith(labels),
			promhttp.InstrumentHandlerCounter(httpRequestsTotal.MustCurryWith(labels), h),
		),
	)
}

func registerRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/healthz", healthzHandler)
	mux.HandleFunc("/readyz", readyzHandler)
	mux.Handle("/api/fast", instrument("/api/fast", fastHandler))
	mux.Handle("/api/slow", instrument("/api/slow", slowHandler))
	mux.Handle("/api/error", instrument("/api/error", errorHandler))
	mux.Handle("/api/flaky", instrument("/api/flaky", flakyHandler))
	mux.Handle("/metrics", promhttp.Handler())
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		runHealthcheck()
		return
	}

	if v := os.Getenv("APP_VERSION"); v != "" {
		version = v
	}
	if c := os.Getenv("APP_COMMIT"); c != "" {
		commit = c
	}
	appBuildInfo.WithLabelValues(version, commit).Set(1)

	port, _ := strconv.Atoi(envOr("APP_PORT", "8080"))
	mux := http.NewServeMux()
	registerRoutes(mux)

	srv := &http.Server{
		Addr:              ":" + strconv.Itoa(port),
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		log.Printf("sample-app version=%s commit=%s listening on %s", version, commit, srv.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server: %v", err)
		}
	}()

	<-ctx.Done()
	log.Println("shutdown signal received")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("shutdown: %v", err)
	}
}

func envOr(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return fallback
}

func runHealthcheck() {
	port := envOr("APP_PORT", "8080")
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get("http://127.0.0.1:" + port + "/healthz")
	if err != nil {
		log.Printf("healthcheck: %v", err)
		os.Exit(1)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		log.Printf("healthcheck: status %d", resp.StatusCode)
		os.Exit(1)
	}
}
