package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHandlers(t *testing.T) {
	cases := []struct {
		name      string
		handler   http.HandlerFunc
		wantCodes []int
	}{
		{"healthz", healthzHandler, []int{200}},
		{"readyz", readyzHandler, []int{200}},
		{"fast", fastHandler, []int{200}},
		{"slow", slowHandler, []int{200}},
		{"error", errorHandler, []int{200, 500}},
		{"flaky", flakyHandler, []int{200, 429, 503}},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/", nil)
			rec := httptest.NewRecorder()
			tc.handler(rec, req)

			got := rec.Code
			ok := false
			for _, c := range tc.wantCodes {
				if got == c {
					ok = true
					break
				}
			}
			if !ok {
				t.Fatalf("%s: status %d not in %v", tc.name, got, tc.wantCodes)
			}
		})
	}
}

func TestRoutesRegister(t *testing.T) {
	mux := http.NewServeMux()
	registerRoutes(mux)

	for _, path := range []string{"/healthz", "/readyz", "/api/fast", "/api/slow", "/api/error", "/api/flaky", "/metrics"} {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		_, pattern := mux.Handler(req)
		if pattern == "" {
			t.Fatalf("no handler registered for %s", path)
		}
	}
}
