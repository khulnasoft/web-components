//go:build integration
// +build integration

package test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/khulnasoft/typosearch-go/v2/typosearch/api"
)

func TestCollectionAliasRetrieve(t *testing.T) {
	collectionName := createNewCollection(t, "companies")
	aliasName := newUUIDName("companies-alias")
	expectedResult := newCollectionAlias(collectionName, aliasName)

	body := &api.CollectionAliasSchema{CollectionName: collectionName}
	_, err := typosearchClient.Aliases().Upsert(context.Background(), aliasName, body)
	require.NoError(t, err)

	result, err := typosearchClient.Alias(aliasName).Retrieve(context.Background())

	require.NoError(t, err)
	require.Equal(t, expectedResult, result)
}

func TestCollectionAliasDelete(t *testing.T) {
	collectionName := createNewCollection(t, "companies")
	aliasName := newUUIDName("companies-alias")
	expectedResult := newCollectionAlias(collectionName, aliasName)

	body := &api.CollectionAliasSchema{CollectionName: collectionName}
	_, err := typosearchClient.Aliases().Upsert(context.Background(), aliasName, body)
	require.NoError(t, err)

	result, err := typosearchClient.Alias(aliasName).Delete(context.Background())

	require.NoError(t, err)
	require.Equal(t, expectedResult, result)

	_, err = typosearchClient.Alias(aliasName).Retrieve(context.Background())
	require.Error(t, err)
}
