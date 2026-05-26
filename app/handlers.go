package main

import (
	"fmt"
	"math/rand"
	"net/http"
	"strconv"
	"time"
)

func healthzHandler(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "ok")
}

func readyzHandler(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "ready")
}

func fastHandler(w http.ResponseWriter, _ *http.Request) {
	time.Sleep(time.Duration(5+rand.Intn(15)) * time.Millisecond)
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "fast")
}

func slowHandler(w http.ResponseWriter, _ *http.Request) {
	time.Sleep(time.Duration(300+rand.Intn(900)) * time.Millisecond)
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "slow")
}

func errorHandler(w http.ResponseWriter, _ *http.Request) {
	if rand.Float64() < 0.3 {
		http.Error(w, "synthetic failure", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "ok")
}

func flakyHandler(w http.ResponseWriter, _ *http.Request) {
	statuses := []int{
		http.StatusOK, http.StatusOK, http.StatusOK,
		http.StatusTooManyRequests,
		http.StatusServiceUnavailable,
	}
	code := statuses[rand.Intn(len(statuses))]
	w.WriteHeader(code)
	fmt.Fprintln(w, strconv.Itoa(code))
}
