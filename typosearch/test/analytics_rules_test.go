//go:build integration
// +build integration

package test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/khulnasoft/typosearch-go/v2/typosearch/api"
)

func TestAnalyticsRulesUpsert(t *testing.T) {
	collectionName := createNewCollection(t, "analytics-rules-collection")
	eventName := newUUIDName("event")
	ruleSchema := newAnalyticsRuleUpsertSchema(collectionName, eventName)
	ruleName := newUUIDName("test-rule")
	expectedData := newAnalyticsRule(ruleName, collectionName, eventName)

	result, err := typosearchClient.Analytics().Rules().Upsert(context.Background(), ruleName, ruleSchema)

	require.NoError(t, err)
	require.Equal(t, expectedData, result)
}

func TestAnalyticsRulesRetrieve(t *testing.T) {
	collectionName := createNewCollection(t, "analytics-rules-collection")
	eventName := newUUIDName("event")
	expectedRule := createNewAnalyticsRule(t, collectionName, eventName)

	results, err := typosearchClient.Analytics().Rules().Retrieve(context.Background())

	require.NoError(t, err)
	require.True(t, len(results) >= 1, "number of rules is invalid")

	var result *api.AnalyticsRuleSchema
	for _, rule := range results {
		if rule.Name == expectedRule.Name {
			result = rule
			break
		}
	}

	require.NotNil(t, result, "rule not found")
	require.Equal(t, expectedRule, result)
}
