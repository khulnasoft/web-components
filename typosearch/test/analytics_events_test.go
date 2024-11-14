//go:build integration
// +build integration

package test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/khulnasoft/typosearch-go/v2/typosearch/api"
)

func TestAnalyticsEventsCreate(t *testing.T) {
	eventName := newUUIDName("event")
	collectionName := createNewCollection(t, "analytics-rules-collection")
	createNewAnalyticsRule(t, collectionName, eventName)

	result, err := typosearchClient.Analytics().Events().Create(context.Background(), &api.AnalyticsEventCreateSchema{
		Type: "click",
		Name: eventName,
		Data: map[string]interface{}{
			"q":       "nike shoes",
			"doc_id":  "1024",
			"user_id": "111112",
		},
	})

	require.NoError(t, err)
	require.True(t, result.Ok)
}
