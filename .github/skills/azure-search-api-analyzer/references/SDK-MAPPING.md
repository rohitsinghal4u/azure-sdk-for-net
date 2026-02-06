# SDK Mapping Patterns

This document explains how swagger/OpenAPI elements map to Azure SDK for .NET implementations.

## Overview

The Azure.Search.Documents SDK uses AutoRest to generate code from swagger specifications. Understanding the mapping helps predict SDK changes from API changes.

## Operation Mappings

### Path → Client Method

| Swagger Path | HTTP Method | SDK Method Pattern |
|--------------|-------------|-------------------|
| `/indexes` | GET | `GetIndexes()` / `GetIndexesAsync()` |
| `/indexes` | POST | `CreateIndex()` / `CreateIndexAsync()` |
| `/indexes('{name}')` | GET | `GetIndex(string name)` |
| `/indexes('{name}')` | PUT | `CreateOrUpdateIndex(SearchIndex index)` |
| `/indexes('{name}')` | DELETE | `DeleteIndex(string name)` |
| `/docs` | POST (search) | `Search<T>(string searchText)` |

### Operation ID → Method Name

```
OperationId: Indexes_List → GetIndexes
OperationId: Indexes_Create → CreateIndex
OperationId: Indexes_Get → GetIndex
OperationId: Indexes_CreateOrUpdate → CreateOrUpdateIndex
OperationId: Indexes_Delete → DeleteIndex
OperationId: Documents_Search → Search
```

### Client Organization

| Swagger Tag | SDK Client |
|-------------|------------|
| Indexes | `SearchIndexClient` |
| Indexers | `SearchIndexerClient` |
| DataSources | `SearchIndexerClient` |
| Skillsets | `SearchIndexerClient` |
| SynonymMaps | `SearchIndexClient` |
| Documents | `SearchClient` |
| KnowledgeBases | `SearchIndexClient` (or new client) |

## Model Mappings

### Definition → Class

```
Swagger: SearchIndex → SDK: SearchIndex
Swagger: SearchField → SDK: SearchField
Swagger: SearchIndexer → SDK: SearchIndexer
```

### Property → Property

| Swagger Type | C# Type |
|--------------|---------|
| `string` | `string` |
| `string` (format: date-time) | `DateTimeOffset?` |
| `string` (format: uri) | `Uri` |
| `integer` (format: int32) | `int` / `int?` |
| `integer` (format: int64) | `long` / `long?` |
| `number` (format: double) | `double` / `double?` |
| `boolean` | `bool` / `bool?` |
| `array` | `IList<T>` / `IReadOnlyList<T>` |
| `object` (with $ref) | Referenced type |
| `object` (additionalProperties) | `IDictionary<string, T>` |

### Required Properties

```json
{
  "required": ["name", "fields"],
  "properties": {
    "name": { "type": "string" },      // Non-nullable in SDK
    "fields": { "type": "array" },     // Non-nullable in SDK
    "description": { "type": "string" } // Nullable in SDK
  }
}
```

```csharp
public class SearchIndex
{
    public SearchIndex(string name, IEnumerable<SearchField> fields)
    {
        Name = name ?? throw new ArgumentNullException(nameof(name));
        Fields = fields?.ToList() ?? throw new ArgumentNullException(nameof(fields));
    }

    public string Name { get; }
    public IList<SearchField> Fields { get; }
    public string? Description { get; set; }  // Optional
}
```

## Enum Mappings

### Fixed Enum (modelAsString: false)

```json
{
  "SearchMode": {
    "type": "string",
    "enum": ["any", "all"],
    "x-ms-enum": {
      "name": "SearchMode",
      "modelAsString": false
    }
  }
}
```

```csharp
public enum SearchMode
{
    Any,
    All
}
```

### Extensible Enum (modelAsString: true)

```json
{
  "LexicalAnalyzerName": {
    "type": "string",
    "enum": ["standard", "simple", "keyword"],
    "x-ms-enum": {
      "name": "LexicalAnalyzerName",
      "modelAsString": true
    }
  }
}
```

```csharp
public readonly struct LexicalAnalyzerName : IEquatable<LexicalAnalyzerName>
{
    private readonly string _value;

    public LexicalAnalyzerName(string value) => _value = value;

    public static LexicalAnalyzerName Standard { get; } = new("standard");
    public static LexicalAnalyzerName Simple { get; } = new("simple");
    public static LexicalAnalyzerName Keyword { get; } = new("keyword");

    public static implicit operator LexicalAnalyzerName(string value) => new(value);
}
```

## Inheritance Mappings

### Polymorphic Types

```json
{
  "SearchIndexerSkill": {
    "discriminator": "@odata.type",
    "properties": {
      "@odata.type": { "type": "string" }
    }
  },
  "OcrSkill": {
    "allOf": [{ "$ref": "#/definitions/SearchIndexerSkill" }],
    "x-ms-discriminator-value": "#Microsoft.Skills.Vision.OcrSkill"
  }
}
```

```csharp
public abstract partial class SearchIndexerSkill
{
    internal SearchIndexerSkill() { }

    // Discriminator used for serialization
}

public partial class OcrSkill : SearchIndexerSkill
{
    public OcrSkill(/* required params */)
    {
    }
}
```

## Parameter Mappings

### Path Parameters

```json
{
  "parameters": [
    { "name": "indexName", "in": "path", "type": "string", "required": true }
  ]
}
```

```csharp
public Response<SearchIndex> GetIndex(string indexName, CancellationToken cancellationToken = default)
```

### Query Parameters

```json
{
  "parameters": [
    { "name": "$select", "in": "query", "type": "array", "items": { "type": "string" } }
  ]
}
```

```csharp
public class GetIndexOptions
{
    public IList<string> Select { get; } = new List<string>();
}

public Response<SearchIndex> GetIndex(string indexName, GetIndexOptions options = null, ...)
```

### Header Parameters

```json
{
  "parameters": [
    { "name": "If-Match", "in": "header", "type": "string" }
  ]
}
```

```csharp
public Response<SearchIndex> CreateOrUpdateIndex(
    SearchIndex index,
    bool onlyIfUnchanged = false,  // Uses ETag from index
    CancellationToken cancellationToken = default)
```

### Body Parameters

```json
{
  "parameters": [
    { "name": "index", "in": "body", "schema": { "$ref": "#/definitions/SearchIndex" } }
  ]
}
```

```csharp
public Response<SearchIndex> CreateIndex(SearchIndex index, CancellationToken cancellationToken = default)
```

## Response Mappings

### Single Object

```json
{
  "responses": {
    "200": {
      "schema": { "$ref": "#/definitions/SearchIndex" }
    }
  }
}
```

```csharp
public Response<SearchIndex> GetIndex(string indexName, ...)
public Task<Response<SearchIndex>> GetIndexAsync(string indexName, ...)
```

### Paged Results

```json
{
  "responses": {
    "200": {
      "schema": {
        "properties": {
          "value": { "type": "array", "items": { "$ref": "#/definitions/SearchIndex" } },
          "@odata.nextLink": { "type": "string" }
        }
      }
    }
  }
}
```

```csharp
public Pageable<SearchIndex> GetIndexes(CancellationToken cancellationToken = default)
public AsyncPageable<SearchIndex> GetIndexesAsync(CancellationToken cancellationToken = default)
```

## Customization Mappings

### Rename via x-ms-client-name

```json
{
  "OldName": {
    "x-ms-client-name": "NewName"
  }
}
```

Or in autorest.md:
```yaml
directive:
- from: searchservice.json
  where: $.definitions.OldName
  transform: $["x-ms-client-name"] = "NewName"
```

### Hide via x-accessibility

```json
{
  "InternalType": {
    "x-accessibility": "internal"
  }
}
```

### SDK Customization via CodeGenModel

```csharp
// Hide generated type
[CodeGenModel("SwaggerTypeName")]
internal partial class SwaggerTypeName { }

// Create public replacement
public class PublicTypeName
{
    // Custom implementation
}
```

## Namespace Mappings

| Swagger Location | SDK Namespace |
|------------------|---------------|
| searchindex.json definitions | `Azure.Search.Documents.Models` |
| searchservice.json definitions | `Azure.Search.Documents.Indexes.Models` |
| knowledgebase.json definitions | `Azure.Search.Documents.KnowledgeBases.Models` |

## Common Patterns

### Factory Methods for Testability

Every public model should have a corresponding factory method:

```csharp
public static class SearchModelFactory
{
    public static SearchIndex SearchIndex(
        string name = default,
        IEnumerable<SearchField> fields = default,
        string description = default)
    {
        return new SearchIndex(name, fields?.ToList())
        {
            Description = description
        };
    }
}
```

### Sync/Async Pairs

Every async method has a sync counterpart:

```csharp
public virtual Response<SearchIndex> GetIndex(string indexName, CancellationToken cancellationToken = default)
public virtual async Task<Response<SearchIndex>> GetIndexAsync(string indexName, CancellationToken cancellationToken = default)
```

### Options Pattern

Complex operations use options classes:

```csharp
public class SearchOptions
{
    public string Filter { get; set; }
    public IList<string> SearchFields { get; }
    public int? Size { get; set; }
}

public Response<SearchResults<T>> Search<T>(string searchText, SearchOptions options = null, ...)
```
