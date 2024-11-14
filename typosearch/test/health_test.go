//go:build integration
// +build integration

package test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestHealthStatus(t *testing.T) {
	t.Parallel()
	healthy, err := typosearchClient.Health(context.Background(), 2*time.Second)
	assert.NoError(t, err)
	assert.True(t, healthy)
}
