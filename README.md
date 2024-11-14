# typosearch-go

[![Build Status](https://cloud.drone.io/api/badges/khulnasoft/typosearch-go/status.svg)](https://cloud.drone.io/khulnasoft/typosearch-go)
[![GoReportCard Status](https://goreportcard.com/badge/github.com/khulnasoft/typosearch-go/v2)](https://goreportcard.com/report/github.com/khulnasoft/typosearch-go/v2)
[![Go Reference](https://pkg.go.dev/badge/github.com/khulnasoft/typosearch-go/v2.svg)](https://pkg.go.dev/github.com/khulnasoft/typosearch-go/v2)
[![GitHub release](https://img.shields.io/github/v/release/khulnasoft/typosearch-go)](https://github.com/khulnasoft/typosearch-go/releases/latest)
[![Gitter](https://badges.gitter.im/typosearch-go/community.svg)](https://gitter.im/typosearch-go/community)

Go client for the Typosearch API: https://github.com/khulnasoft/typosearch

## Installation

```
go get github.com/khulnasoft/typosearch-go/v2/typosearch
```

## Usage

Import the the package into your code :

```go
import "github.com/khulnasoft/typosearch-go/v2/typosearch"
```

Create new client:

```go
client := typosearch.NewClient(
	    typosearch.WithServer("http://localhost:8108"),
	    typosearch.WithAPIKey("<API_KEY>"))
```

New client with advanced configuration options (see godoc):

```go
client := typosearch.NewClient(
		typosearch.WithServer("http://localhost:8108"),
		typosearch.WithAPIKey("<API_KEY>"),
		typosearch.WithConnectionTimeout(5*time.Second),
		typosearch.WithCircuitBreakerMaxRequests(50),
		typosearch.WithCircuitBreakerInterval(2*time.Minute),
		typosearch.WithCircuitBreakerTimeout(1*time.Minute),
	)
```

New client with multi-node configuration options:

```go
client := typosearch.NewClient(
		typosearch.WithNearestNode("https://xxx.a1.typosearch.net:443"),
		typosearch.WithNodes([]string{
			"https://xxx-1.a1.typosearch.net:443",
			"https://xxx-2.a1.typosearch.net:443",
			"https://xxx-3.a1.typosearch.net:443",
		}),
		typosearch.WithAPIKey("<API_KEY>"),
		typosearch.WithNumRetries(5),
		typosearch.WithRetryInterval(1*time.Second),
		typosearch.WithHealthcheckInterval(2*time.Minute),
	)
```

You can also find some examples in [integration tests](https://github.com/khulnasoft/typosearch-go/tree/master/typosearch/test).

### Create a collection

```go
	schema := &api.CollectionSchema{
		Name: "companies",
		Fields: []api.Field{
			{
				Name: "company_name",
				Type: "string",
			},
			{
				Name: "num_employees",
				Type: "int32",
			},
			{
				Name:  "country",
				Type:  "string",
				Facet: true,
			},
		},
		DefaultSortingField: pointer.String("num_employees"),
	}

	client.Collections().Create(context.Background(), schema)
```

### Typed document operations

In `v2.0.0`+, the client allows you to define a document struct to be used type for some of the document operations.

To do that, you've to use `typosearch.GenericCollection`:

```go
type companyDocument struct {
    ID           string `json:"id"`
    CompanyName  string `json:"company_name"`
    NumEmployees int    `json:"num_employees"`
    Country      string `json:"country"`
}

// doc is a typed document
doc, err := typosearch.GenericCollection[*companyDocument](typosearchClient, collectionName).Document("123").Retrieve(context.Background())
```

### Index a document

```go
	document := struct {
		ID           string `json:"id"`
		CompanyName  string `json:"company_name"`
		NumEmployees int    `json:"num_employees"`
		Country      string `json:"country"`
	}{
		ID:           "123",
		CompanyName:  "Stark Industries",
		NumEmployees: 5215,
		Country:      "USA",
	}

	client.Collection("companies").Documents().Create(context.Background(), document)
```

### Upserting a document

```go
	newDocument := struct {
		ID           string `json:"id"`
		CompanyName  string `json:"company_name"`
		NumEmployees int    `json:"num_employees"`
		Country      string `json:"country"`
	}{
		ID:           "123",
		CompanyName:  "Stark Industries",
		NumEmployees: 5215,
		Country:      "USA",
	}

	client.Collection("companies").Documents().Upsert(context.Background(), newDocument)
```

### Search a collection

```go
	searchParameters := &api.SearchCollectionParams{
		Q:        pointer.String("stark"),
		QueryBy:  pointer.String("company_name"),
		FilterBy: pointer.String("num_employees:>100"),
		SortBy:   &([]string{"num_employees:desc"}),
	}

	client.Collection("companies").Documents().Search(context.Background(), searchParameters)
```

for the supporting multiple `QueryBy` params, you can add `,` after each field

```go
	searchParameters := &api.SearchCollectionParams{
		Q:        pointer.String("stark"),
		QueryBy:  pointer.String("company_name, country"),
		FilterBy: pointer.String("num_employees:>100"),
		SortBy:   &([]string{"num_employees:desc"}),
	}

	client.Collection("companies").Documents().Search(context.Background(), searchParameters)
```

### Retrieve a document

```go
client.Collection("companies").Document("123").Retrieve(context.Background())
```

### Update a document

```go
	document := struct {
		CompanyName  string `json:"company_name"`
		NumEmployees int    `json:"num_employees"`
	}{
		CompanyName:  "Stark Industries",
		NumEmployees: 5500,
	}

	client.Collection("companies").Document("123").Update(context.Background(), document)
```

### Delete an individual document

```go
client.Collection("companies").Document("123").Delete(context.Background())
```

### Delete a bunch of documents

```go
filter := &api.DeleteDocumentsParams{FilterBy: "num_employees:>100", BatchSize: 100}
client.Collection("companies").Documents().Delete(context.Background(), filter)
```

### Retrieve a collection

```go
client.Collection("companies").Retrieve(context.Background())
```

### Export documents from a collection

```go
client.Collection("companies").Documents().Export(context.Background())
```

### Import documents into a collection

The documents to be imported can be either an array of document objects or be formatted as a newline delimited JSON string (see [JSONL](https://jsonlines.org)).

Import an array of documents:

```go
	documents := []interface{}{
		struct {
			ID           string `json:"id"`
			CompanyName  string `json:"companyName"`
			NumEmployees int    `json:"numEmployees"`
			Country      string `json:"country"`
		}{
			ID:           "123",
			CompanyName:  "Stark Industries",
			NumEmployees: 5215,
			Country:      "USA",
		},
	}
	params := &api.ImportDocumentsParams{
		Action:    pointer.String("create"),
		BatchSize: pointer.Int(40),
	}

	client.Collection("companies").Documents().Import(context.Background(), documents, params)
```

Import a JSONL file:

```go
	params := &api.ImportDocumentsParams{
		Action:    pointer.String("create"),
		BatchSize: pointer.Int(40),
	}
	importBody, err := os.Open("documents.jsonl")
	// defer close, error handling ...

	client.Collection("companies").Documents().ImportJsonl(context.Background(), importBody, params)
```

### List all collections

```go
client.Collections().Retrieve(context.Background())
```

### Drop a collection

```go
client.Collection("companies").Delete(context.Background())
```

### Create an API Key

```go
	keySchema := &api.ApiKeySchema{
		Description: "Search-only key.",
		Actions:     []string{"documents:search"},
		Collections: []string{"companies"},
		ExpiresAt:   time.Now().AddDate(0, 6, 0).Unix(),
	}

	client.Keys().Create(context.Background(), keySchema)
```

### Retrieve an API Key

```go
client.Key(1).Retrieve(context.Background())
```

### List all keys

```go
client.Keys().Retrieve(context.Background())
```

### Delete API Key

```go
client.Key(1).Delete(context.Background())
```

### Create or update an override

```go
	override := &api.SearchOverrideSchema{
		Rule: api.SearchOverrideRule{
			Query: "apple",
			Match: "exact",
		},
		Includes: []api.SearchOverrideInclude{
			{
				Id:       "422",
				Position: 1,
			},
			{
				Id:       "54",
				Position: 2,
			},
		},
		Excludes: []api.SearchOverrideExclude{
			{
				Id: "287",
			},
		},
	}

	client.Collection("companies").Overrides().Upsert(context.Background(), "customize-apple", override)
```

### List all overrides

```go
client.Collection("companies").Overrides().Retrieve(context.Background())
```

### Delete an override

```go
client.Collection("companies").Override("customize-apple").Delete(context.Background())
```

### Create or Update an alias

```go
	body := &api.CollectionAliasSchema{CollectionName: "companies_june11"}
	client.Aliases().Upsert("companies", body)
```

### Retrieve an alias

```go
client.Alias("companies").Retrieve(context.Background())
```

### List all aliases

```go
client.Aliases().Retrieve(context.Background())
```

### Delete an alias

```go
client.Alias("companies").Delete(context.Background())
```

### Create or update a multi-way synonym

```go
	synonym := &api.SearchSynonymSchema{
		Synonyms: []string{"blazer", "coat", "jacket"},
	}
	client.Collection("products").Synonyms().Upsert(context.Background(), "coat-synonyms", synonym)
```

### Create or update a one-way synonym

```go
	synonym := &api.SearchSynonymSchema{
		Root:     "blazer",
		Synonyms: []string{"blazer", "coat", "jacket"},
	}
	client.Collection("products").Synonyms().Upsert(context.Background(), "coat-synonyms", synonym)
```

### Retrieve a synonym

```go
client.Collection("products").Synonym("coat-synonyms").Retrieve(context.Background())
```

### List all synonyms

```go
client.Collection("products").Synonyms().Retrieve(context.Background())
```

### Delete a synonym

```go
client.Collection("products").Synonym("coat-synonyms").Delete(context.Background())
```

### Create or update a stopwords set

```go
	stopwords := &api.StopwordsSetUpsertSchema{
		Locale:    pointer.String("en"),
		Stopwords: []string{"Germany", "France", "Italy", "United States"},
	}
	client.Stopwords().Upsert(context.Background(), "stopword_set1", stopwords)
```

### Retrieve a stopwords set

```go
client.Stopword("stopword_set1").Retrieve(context.Background())
```

### List all stopwords sets

```go
client.Stopwords().Retrieve(context.Background())
```

### Delete a stopwords set

```go
client.Stopword("stopword_set1").Delete(context.Background())
```

### Create or update a preset

```go
preset := &api.PresetUpsertSchema{}
preset.Value.FromMultiSearchSearchesParameter(api.MultiSearchSearchesParameter{
		Searches: []api.MultiSearchCollectionParameters{
			{
				Collection: "books",
			},
		},
	})
// or: preset.Value.FromSearchParameters(api.SearchParameters{Q: "Books"})

client.Presets().Upsert(context.Background(), "listing-view-preset", preset)
```

### Retrieve a preset

```go
client.Preset("listing-view-preset").Retrieve(context.Background())
```

### List all presets

```go
client.Presets().Retrieve(context.Background())
```

### Delete a preset

```go
client.Preset("listing-view-preset").Delete(context.Background())
```

### Create snapshot (for backups)

```go
client.Operations().Snapshot(context.Background(), "/tmp/typosearch-data-snapshot")
```

### Re-elect Leader

```go
client.Operations().Vote(context.Background())
```

### Cluster Metrics

```go
client.Metrics().Retrieve(context.Background())
```

### API Stats

```go
client.Stats().Retrieve(context.Background())
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/khulnasoft/typosearch-go.

#### Development Workflow Setup

Install dependencies,

```bash
go mod download
```

Update the generated files,

```bash
go generate ./...
```

## License

`typosearch-go` is distributed under the Apache 2 license.
