//go:build integration
// +build integration

package test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/khulnasoft/typosearch-go/v2/typosearch/api/pointer"
)

func TestSearchSynonymRetrieve(t *testing.T) {
	collectionName := createNewCollection(t, "products")
	synonymID := newUUIDName("customize-apple")
	expectedResult := newSearchSynonym(synonymID)

	body := newSearchSynonymSchema()
	_, err := typosearchClient.Collection(collectionName).Synonyms().Upsert(context.Background(), synonymID, body)
	require.NoError(t, err)

	result, err := typosearchClient.Collection(collectionName).Synonym(synonymID).Retrieve(context.Background())

	require.NoError(t, err)
	expectedResult.Root = pointer.String("")
	require.Equal(t, expectedResult, result)
}

func TestSearchSynonymDelete(t *testing.T) {
	collectionName := createNewCollection(t, "products")
	synonymID := newUUIDName("customize-apple")
	expectedResult := newSearchSynonym(synonymID)

	body := newSearchSynonymSchema()
	_, err := typosearchClient.Collection(collectionName).Synonyms().Upsert(context.Background(), synonymID, body)
	require.NoError(t, err)

	result, err := typosearchClient.Collection(collectionName).Synonym(synonymID).Delete(context.Background())

	require.NoError(t, err)
	require.Equal(t, expectedResult.Id, result.Id)

	_, err = typosearchClient.Collection(collectionName).Synonym(synonymID).Retrieve(context.Background())
	require.Error(t, err)
}
