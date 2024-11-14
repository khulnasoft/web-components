go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen -package api -generate client -o $(pwd)/typosearch/api/client_gen.go $(pwd)/typosearch/api/generator/generator.yml
go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen -package api -generate types -o $(pwd)/typosearch/api/types_gen.go $(pwd)/typosearch/api/generator/generator.yml
