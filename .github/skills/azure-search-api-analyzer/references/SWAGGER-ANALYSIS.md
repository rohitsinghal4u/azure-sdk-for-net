# Swagger Analysis Guide

This document provides detailed guidance on analyzing Azure Search swagger/OpenAPI specifications.

## Swagger File Structure

Azure Search uses Swagger 2.0 format. Each file has these main sections:

```json
{
  "swagger": "2.0",
  "info": { ... },           // API metadata
  "host": "...",             // Base URL
  "basePath": "/",           // Path prefix
  "schemes": ["https"],      // Protocol
  "consumes": ["application/json"],
  "produces": ["application/json"],
  "paths": { ... },          // API operations
  "definitions": { ... },    // Data models
  "parameters": { ... },     // Reusable parameters
  "responses": { ... }       // Reusable responses
}
```

## Analyzing Paths (Operations)

### Path Structure

```json
{
  "paths": {
    "/indexes('{indexName}')": {
      "get": {
        "tags": ["Indexes"],
        "operationId": "Indexes_Get",
        "description": "Retrieves an index definition.",
        "parameters": [
          {
            "name": "indexName",
            "in": "path",
            "required": true,
            "type": "string"
          }
        ],
        "responses": {
          "200": {
            "description": "Success",
            "schema": { "$ref": "#/definitions/SearchIndex" }
          }
        }
      },
      "put": { ... },
      "delete": { ... }
    }
  }
}
```

### Key Elements to Compare

| Element | Description | Breaking if Changed |
|---------|-------------|---------------------|
| Path | The URL pattern | Yes (if removed) |
| HTTP Method | GET, POST, PUT, DELETE, PATCH | Yes (if removed) |
| operationId | Unique identifier | No (but affects generated code) |
| Parameters | Input values | Yes (if required added) |
| Request Body | Input schema | Yes (if required fields added) |
| Responses | Output schemas | Potentially |

### Parameter Types

```json
{
  "parameters": [
    { "in": "path", "name": "id", "required": true },      // URL path
    { "in": "query", "name": "api-version", "required": true },  // Query string
    { "in": "header", "name": "x-ms-client-request-id" },  // HTTP header
    { "in": "body", "name": "document", "schema": {...} }  // Request body
  ]
}
```

## Analyzing Definitions (Models)

### Model Structure

```json
{
  "definitions": {
    "SearchIndex": {
      "type": "object",
      "description": "Represents a search index.",
      "required": ["name", "fields"],
      "properties": {
        "name": {
          "type": "string",
          "description": "The name of the index."
        },
        "fields": {
          "type": "array",
          "items": { "$ref": "#/definitions/SearchField" }
        },
        "scoringProfiles": {
          "type": "array",
          "items": { "$ref": "#/definitions/ScoringProfile" }
        }
      }
    }
  }
}
```

### Property Types

| Type | Format | Example |
|------|--------|---------|
| string | - | `"type": "string"` |
| string | date-time | `"type": "string", "format": "date-time"` |
| string | uri | `"type": "string", "format": "uri"` |
| integer | int32 | `"type": "integer", "format": "int32"` |
| integer | int64 | `"type": "integer", "format": "int64"` |
| number | double | `"type": "number", "format": "double"` |
| boolean | - | `"type": "boolean"` |
| array | - | `"type": "array", "items": {...}` |
| object | - | `"type": "object"` or `"$ref": "..."` |

### Inheritance (Polymorphism)

```json
{
  "SearchIndexerSkill": {
    "discriminator": "@odata.type",
    "properties": {
      "@odata.type": { "type": "string" },
      "name": { "type": "string" }
    },
    "required": ["@odata.type"]
  },
  "OcrSkill": {
    "allOf": [
      { "$ref": "#/definitions/SearchIndexerSkill" },
      {
        "properties": {
          "defaultLanguageCode": { "type": "string" }
        }
      }
    ],
    "x-ms-discriminator-value": "#Microsoft.Skills.Vision.OcrSkill"
  }
}
```

## Analyzing Enums

### Enum Structure

```json
{
  "SearchMode": {
    "type": "string",
    "enum": ["any", "all"],
    "x-ms-enum": {
      "name": "SearchMode",
      "modelAsString": true
    },
    "description": "Specifies whether any or all terms must match."
  }
}
```

### Extensible vs Fixed Enums

- `"modelAsString": true` - Extensible enum (SDK generates struct)
- `"modelAsString": false` - Fixed enum (SDK generates enum)

## Common Patterns

### Paged Results

```json
{
  "ListIndexesResult": {
    "properties": {
      "value": {
        "type": "array",
        "items": { "$ref": "#/definitions/SearchIndex" }
      },
      "@odata.nextLink": {
        "type": "string",
        "description": "Link to next page of results"
      }
    }
  }
}
```

### Error Responses

```json
{
  "responses": {
    "default": {
      "description": "Error response",
      "schema": {
        "$ref": "../common-types/data-plane/v1/types.json#/definitions/ErrorResponse"
      }
    }
  }
}
```

### ETags for Concurrency

```json
{
  "parameters": [
    {
      "name": "If-Match",
      "in": "header",
      "type": "string",
      "description": "ETag for optimistic concurrency"
    },
    {
      "name": "If-None-Match",
      "in": "header",
      "type": "string"
    }
  ]
}
```

## Extracting Information with PowerShell

### Load Swagger File

```powershell
$swagger = Get-Content "searchservice.json" -Raw | ConvertFrom-Json
```

### List All Paths

```powershell
$swagger.paths.PSObject.Properties | ForEach-Object {
    Write-Host $_.Name
}
```

### List All Operations

```powershell
$swagger.paths.PSObject.Properties | ForEach-Object {
    $path = $_.Name
    $_.Value.PSObject.Properties |
        Where-Object { $_.Name -match '^(get|post|put|delete|patch)$' } |
        ForEach-Object {
            [PSCustomObject]@{
                Method = $_.Name.ToUpper()
                Path = $path
                OperationId = $_.Value.operationId
                Description = $_.Value.description
            }
        }
} | Format-Table
```

### List All Definitions

```powershell
$swagger.definitions.PSObject.Properties | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        Type = $_.Value.type
        Properties = ($_.Value.properties.PSObject.Properties.Name -join ", ")
    }
} | Format-Table -Wrap
```

### Get Properties of a Model

```powershell
$modelName = "SearchIndex"
$model = $swagger.definitions.$modelName

$model.properties.PSObject.Properties | ForEach-Object {
    $prop = $_.Value
    [PSCustomObject]@{
        Name = $_.Name
        Type = if ($prop.'$ref') { $prop.'$ref'.Split('/')[-1] } else { $prop.type }
        Required = $_.Name -in $model.required
        Description = $prop.description
    }
} | Format-Table -Wrap
```

### Find Enum Definitions

```powershell
$swagger.definitions.PSObject.Properties |
    Where-Object { $_.Value.enum } |
    ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            Values = $_.Value.enum -join ", "
            Extensible = $_.Value.'x-ms-enum'.modelAsString
        }
    } | Format-Table
```

## Comparing Swagger Files

### Compare Definitions

```powershell
function Compare-SwaggerDefinitions {
    param($Previous, $Current)

    $prevDefs = $Previous.definitions.PSObject.Properties.Name
    $currDefs = $Current.definitions.PSObject.Properties.Name

    @{
        Added = $currDefs | Where-Object { $_ -notin $prevDefs }
        Removed = $prevDefs | Where-Object { $_ -notin $currDefs }
        Common = $currDefs | Where-Object { $_ -in $prevDefs }
    }
}
```

### Compare Model Properties

```powershell
function Compare-ModelProperties {
    param($Previous, $Current, $ModelName)

    $prevProps = $Previous.definitions.$ModelName.properties.PSObject.Properties.Name
    $currProps = $Current.definitions.$ModelName.properties.PSObject.Properties.Name

    @{
        Added = $currProps | Where-Object { $_ -notin $prevProps }
        Removed = $prevProps | Where-Object { $_ -notin $currProps }
    }
}
```

### Compare Operations

```powershell
function Get-Operations {
    param($Swagger)

    $swagger.paths.PSObject.Properties | ForEach-Object {
        $path = $_.Name
        $_.Value.PSObject.Properties |
            Where-Object { $_.Name -match '^(get|post|put|delete|patch)$' } |
            ForEach-Object {
                "$($_.Name.ToUpper()) $path"
            }
    }
}

function Compare-Operations {
    param($Previous, $Current)

    $prevOps = Get-Operations $Previous
    $currOps = Get-Operations $Current

    @{
        Added = $currOps | Where-Object { $_ -notin $prevOps }
        Removed = $prevOps | Where-Object { $_ -notin $currOps }
    }
}
```

## Azure Search Specific Patterns

### OData Type Discriminator

Many Azure Search models use `@odata.type` for polymorphism:

```json
{
  "@odata.type": "#Microsoft.Skills.Text.KeyPhraseExtractionSkill"
}
```

### Vector Search Extensions

Vector search adds specific extensions:

```json
{
  "x-ms-embedding-vector": true
}
```

### Client-Side Naming

Azure-specific naming overrides:

```json
{
  "x-ms-client-name": "CustomClientName"
}
```

### Accessibility

Internal types marked as:

```json
{
  "x-accessibility": "internal"
}
```
