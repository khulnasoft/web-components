//go:build integration
// +build integration

package test

import (
	"log"
	"os"
	"testing"

	"github.com/khulnasoft/typosearch-go/v2/typosearch"
)

var typosearchClient *typosearch.Client

func TestMain(m *testing.M) {
	os.Exit(testMain(m))
}

func testMain(m *testing.M) int {
	var err error
	typosearchClient, err = setupDB()
	if err != nil {
		log.Printf("failed to setup typosearch db: %v\n", err)
		return 1
	}
	defer stopDB()
	return m.Run()
}
