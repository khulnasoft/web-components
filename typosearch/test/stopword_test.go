//go:build integration
// +build integration

package test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/khulnasoft/typosearch-go/v2/typosearch/api"
	"github.com/khulnasoft/typosearch-go/v2/typosearch/api/pointer"
)

func TestStopwordRetrieve(t *testing.T) {
	stopwordsSetID := newUUIDName("stopwordsSet-test")
	upsertData := &api.StopwordsSetUpsertSchema{
		Locale:    pointer.String("en"),
		Stopwords: []string{"Germany", "France", "Italy", "United States"},
	}

	expectedData := &api.StopwordsSetSchema{
		Id:        stopwordsSetID,
		Locale:    upsertData.Locale,
		Stopwords: upsertData.Stopwords,
	}

	result, err := typosearchClient.Stopwords().Upsert(context.Background(), stopwordsSetID, upsertData)

	require.NoError(t, err)
	require.Equal(t, expectedData, result)

	result, err = typosearchClient.Stopword(stopwordsSetID).Retrieve(context.Background())

	expectedData.Stopwords = []string{"states", "united", "france", "germany", "italy"}

	require.NoError(t, err)
	require.Equal(t, expectedData, result)
}

func TestStopwordDelete(t *testing.T) {
	stopwordsSetID := newUUIDName("stopwordsSet-test")
	upsertData := &api.StopwordsSetUpsertSchema{
		Locale:    pointer.String("en"),
		Stopwords: []string{"Germany", "France", "Italy", "United States"},
	}

	expectedData := &api.StopwordsSetSchema{
		Id:        stopwordsSetID,
		Locale:    upsertData.Locale,
		Stopwords: upsertData.Stopwords,
	}

	result, err := typosearchClient.Stopwords().Upsert(context.Background(), stopwordsSetID, upsertData)
	require.NoError(t, err)
	require.Equal(t, expectedData, result)

	result2, err := typosearchClient.Stopword(stopwordsSetID).Delete(context.Background())

	require.NoError(t, err)
	require.Equal(t, stopwordsSetID, result2.Id)

	_, err = typosearchClient.Stopword(stopwordsSetID).Retrieve(context.Background())
	require.Error(t, err)
}
