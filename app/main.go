package main

import (
	"context"
	"fmt"
	"log"
	"math"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"
)

func main() {
	// Create a channel to listen for OS signals (SIGTERM, SIGINT)
	// This is CRITICAL for Spot Preemption handling.
	stopChan := make(chan os.Signal, 1)
	signal.Notify(stopChan, os.Interrupt, syscall.SIGTERM)

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Image Processing Service: Ready"))
	})

	http.HandleFunc("/process-image", func(w http.ResponseWriter, r *http.Request) {
		// Simulate Image Processing (CPU Intensive)
		start := time.Now()

		// Parse load duration (simulating image size/complexity), default to 50ms
		processingTimeMs := 50
		if durStr := r.URL.Query().Get("duration"); durStr != "" {
			if d, err := strconv.Atoi(durStr); err == nil {
				processingTimeMs = d
			}
		}

		// Simulate pixel manipulation (CPU burn)
		// Simulating: Resize -> Filter -> Compress
		x := 0.0001
		pixelsProcessed := 0
		for time.Since(start) < time.Duration(processingTimeMs)*time.Millisecond {
			x += math.Sqrt(x)
			pixelsProcessed++
		}

		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "Image processed successfully. Filter applied to %d pixels in %v", pixelsProcessed, time.Since(start))
	})

	srv := &http.Server{Addr: ":8080"}

	// Run server in a goroutine
	go func() {
		log.Println("Starting server on :8080")
		if err := srv.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("ListenAndServe(): %v", err)
		}
	}()

	// Block until a signal is received
	sig := <-stopChan
	log.Printf("Received signal: %v. Initiating graceful shutdown...", sig)

	// Graceful shutdown context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	// 1. Sleep to allow Load Balancer update (Dojos: Prestop hook usually does this, but app logic helps)
	log.Println("Waiting 5 seconds before shutting down server...")
	time.Sleep(5 * time.Second)

	// 2. Shut down endpoints
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exiting")
}
