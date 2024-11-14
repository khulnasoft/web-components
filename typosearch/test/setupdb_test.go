//go:build integration && !docker
// +build integration,!docker

package test

import (
	"context"
	"errors"
	"os"
	"time"

	"github.com/khulnasoft/typosearch-go/v2/typosearch"
)

func waitHealthyStatus(client *typosearch.Client, timeout time.Duration) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(1 * time.Second):
			if healthy, _ := client.Health(context.Background(), 2*time.Second); !healthy {
				continue
			}
			return nil
		}
	}
}

func setupDB() (*typosearch.Client, error) {
	url := os.Getenv("TYPOSEARCH_URL")
	apiKey := os.Getenv("TYPOSEARCH_API_KEY")
	if len(url) == 0 || len(apiKey) == 0 {
		return nil, errors.New("TYPOSEARCH_URL or TYPOSEARCH_API_KEY env variable is empty!")
	}
	client := typosearch.NewClient(
		typosearch.WithServer(url),
		typosearch.WithAPIKey(apiKey))
	if err := waitHealthyStatus(client, 1*time.Minute); err != nil {
		return nil, err
	}
	return client, nil
}

func stopDB() error {
	return nil
}
