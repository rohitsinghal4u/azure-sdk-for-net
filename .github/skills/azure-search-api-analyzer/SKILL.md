---
name: azure-search-api-analyzer
description: Analyzes changes between azure-rest-api-specs commits to understand API modifications for Azure Search. Compares swagger/OpenAPI specifications, identifies new operations, models, properties, breaking changes, and generates a comprehensive change summary to pass to the azure-search-sdk-release skill for SDK implementation.
metadata:
  author: azure-sdk
  version: "1.0"
  service: search
---

# Azure Search API Analyzer Skill

This skill analyzes changes between azure-rest-api-specs commits to understand what API modifications have been made. The analysis output is used as context for the azure-search-sdk-release skill.

## Prerequisites

- Git installed and configured
- `azure-rest-api-specs` repository cloned locally
- PowerShell 7 or higher
- Basic understanding of OpenAPI/Swagger specifications

## Workflow Overview

1. **Identify commits** - Get the previous and new commit SHAs
2. **Extract swagger files** - Get the relevant API specification files
3. **Analyze operations** - Compare API operations (endpoints)
4. **Analyze models** - Compare data models (definitions)
5. **Categorize changes** - Classify as additions, modifications, or removals
6. **Generate change summary** - Create structured output for SDK implementation
7. **Pass to SDK-release skill** - Provide context for code generation

---

## Step 1: Identify Commits

### Goal
Establish the baseline (previous) and target (new) commits for comparison.

### Required Information
- **Previous commit SHA**: The commit representing the previous API version
- **New commit SHA**: The commit with the new API changes (can be HEAD or branch)
- **API Version**: The new API version string (e.g., `2025-11-01-preview`)

### Actions

1. Navigate to the azure-rest-api-specs repository
2. Identify the commits to compare:
   ```powershell
   cd c:\azure-rest-api-specs

   # Find commits that modified search specifications
   git log --oneline --follow -- specification/search/data-plane/Azure.Search/

   # Get the current HEAD commit
   git rev-parse HEAD
   ```

3. Verify the API version folders exist:
   ```powershell
   # List available API versions
   ls specification/search/data-plane/Azure.Search/preview/
   ls specification/search/data-plane/Azure.Search/stable/
   ```

---

## Step 2: Extract Swagger Files

### Goal
Retrieve the swagger specification files from both commits for comparison.

### Azure Search Swagger Files

The Azure Search API is defined in these files:
| File | Description |
|------|-------------|
| `searchindex.json` | Document operations (search, autocomplete, suggest, get/index documents) |
| `searchservice.json` | Management operations (indexes, indexers, skillsets, data sources, synonyms) |
| `knowledgebase.json` | Knowledge base operations (newer API versions) |

### File Locations
```
specification/search/data-plane/Azure.Search/
├── preview/
│   └── {api-version}/
│       ├── searchindex.json
│       ├── searchservice.json
│       └── knowledgebase.json (if applicable)
└── stable/
    └── {api-version}/
        ├── searchindex.json
        └── searchservice.json
```

### Actions

1. Extract files from previous commit:
   ```powershell
   $previousCommit = "<previous-sha>"
   $apiVersion = "2025-05-01-preview"
   $basePath = "specification/search/data-plane/Azure.Search/preview/$apiVersion"

   git show ${previousCommit}:${basePath}/searchindex.json > previous-searchindex.json
   git show ${previousCommit}:${basePath}/searchservice.json > previous-searchservice.json
   ```

2. Extract files from new commit (or use current):
   ```powershell
   $newCommit = "<new-sha>"  # or "HEAD"

   git show ${newCommit}:${basePath}/searchindex.json > new-searchindex.json
   git show ${newCommit}:${basePath}/searchservice.json > new-searchservice.json
   ```

---

## Step 3: Analyze Operations

### Goal
Compare API operations (paths/endpoints) between versions.

### Swagger Operations Structure

```json
{
  "paths": {
    "/indexes": {
      "get": {
        "operationId": "Indexes_List",
        "description": "Lists all indexes...",
        "parameters": [...],
        "responses": {...}
      },
      "post": {
        "operationId": "Indexes_Create",
        ...
      }
    }
  }
}
```

### What to Analyze

| Element | Check For |
|---------|-----------|
| **New paths** | Entirely new endpoints |
| **Removed paths** | Deleted endpoints (breaking) |
| **New operations** | New HTTP methods on existing paths |
| **Changed parameters** | Added/removed/modified parameters |
| **Changed responses** | Modified response schemas |
| **Operation IDs** | Renamed operations |

### Analysis Pattern

```powershell
# Parse swagger files
$previous = Get-Content previous-searchservice.json | ConvertFrom-Json
$new = Get-Content new-searchservice.json | ConvertFrom-Json

# Compare paths
$previousPaths = $previous.paths.PSObject.Properties.Name
$newPaths = $new.paths.PSObject.Properties.Name

# Find additions
$addedPaths = $newPaths | Where-Object { $_ -notin $previousPaths }

# Find removals
$removedPaths = $previousPaths | Where-Object { $_ -notin $newPaths }
```

---

## Step 4: Analyze Models

### Goal
Compare data models (definitions/schemas) between versions.

### Swagger Definitions Structure

```json
{
  "definitions": {
    "SearchIndex": {
      "type": "object",
      "description": "Represents a search index.",
      "properties": {
        "name": {
          "type": "string",
          "description": "The name of the index."
        },
        "fields": {
          "type": "array",
          "items": { "$ref": "#/definitions/SearchField" }
        }
      },
      "required": ["name", "fields"]
    }
  }
}
```

### What to Analyze

| Element | Check For |
|---------|-----------|
| **New models** | Entirely new type definitions |
| **Removed models** | Deleted types (breaking) |
| **New properties** | Added fields to existing types |
| **Removed properties** | Deleted fields (breaking) |
| **Changed types** | Property type modifications |
| **New enums** | New enumeration values |
| **Removed enums** | Deleted enum values (breaking) |
| **Required changes** | Changes to required fields |

### Key Model Categories

1. **Core Models**: `SearchIndex`, `SearchField`, `SearchDocument`
2. **Indexer Models**: `SearchIndexer`, `SearchIndexerDataSource`, `SearchIndexerSkillset`
3. **Query Models**: `SearchRequest`, `SearchResult`, `SuggestRequest`
4. **Skill Models**: `SearchIndexerSkill` and its subtypes
5. **Vector Models**: `VectorSearch*`, `VectorQuery`
6. **Knowledge Models**: `KnowledgeBase*`, `KnowledgeSource*`

---

## Step 5: Categorize Changes

### Goal
Classify all identified changes into actionable categories.

### Change Categories

#### 1. New Features (Additive)
- New API operations
- New model types
- New properties on existing types
- New enum values
- New optional parameters

**SDK Impact**: Generate new classes, methods, properties

#### 2. Enhancements (Non-breaking modifications)
- Updated descriptions
- Relaxed constraints (required → optional)
- Extended enum values
- Added optional parameters

**SDK Impact**: Update documentation, potentially add new overloads

#### 3. Breaking Changes
- Removed operations
- Removed models
- Removed properties
- Changed property types
- Tightened constraints (optional → required)
- Renamed operations/models

**SDK Impact**: Requires careful handling, documentation, migration notes

#### 4. Deprecations
- Marked as deprecated but still present
- Replaced by newer alternatives

**SDK Impact**: Add obsolete attributes, update documentation

### Classification Template

```markdown
## API Changes: {API_VERSION}

### New Features
- [ ] New operation: `POST /newEndpoint` - {description}
- [ ] New model: `NewModelType` - {description}
- [ ] New property: `ExistingModel.newProperty` - {type}, {description}

### Enhancements
- [ ] Updated description: `Model.property`
- [ ] New optional parameter: `operation?newParam={value}`

### Breaking Changes
- [ ] Removed operation: `DELETE /oldEndpoint`
- [ ] Removed model: `DeprecatedType`
- [ ] Changed type: `Model.property` string → int

### Deprecations
- [ ] Deprecated: `OldOperation` - use `NewOperation` instead
```

---

## Step 6: Generate Change Summary

### Goal
Create a structured summary and save it to the SDK-release skill's references folder for automatic consumption.

### Output Location

The change summary is automatically written to:
```
.github/skills/azure-search-sdk-release/references/API-ANALYSIS-{api-version}.md
```

This allows the SDK-release skill to dynamically read the analysis when starting its workflow.

### Generate Using Script

```powershell
# From the azure-rest-api-specs repository
$analyzerPath = "c:\azure-sdk-for-net\.github\skills\azure-search-api-analyzer\scripts"

# Generate and output to sdk-release references folder (default)
& "$analyzerPath\Generate-ChangeSummary.ps1" `
    -PreviousCommit "abc123" `
    -ApiVersion "2025-11-01-preview"

# Or specify custom output path
& "$analyzerPath\Generate-ChangeSummary.ps1" `
    -PreviousCommit "abc123" `
    -ApiVersion "2025-11-01-preview" `
    -OutputPath "my-custom-analysis.md"
```

### Change Summary Format

```markdown
# Azure Search API Change Summary

## Metadata
- **Previous API Version**: 2025-05-01-preview
- **New API Version**: 2025-11-01-preview
- **Previous Commit**: abc123...
- **New Commit**: def456...
- **Track**: preview

## Summary Statistics
- New Operations: X
- Modified Operations: Y
- Removed Operations: Z
- New Models: A
- Modified Models: B
- Removed Models: C

## New Operations

### `POST /knowledgebases`
- **Operation ID**: KnowledgeBases_Create
- **Description**: Creates a new knowledge base
- **Request Body**: KnowledgeBase
- **Response**: KnowledgeBase
- **SDK Method**: `SearchIndexClient.CreateKnowledgeBase()`

### `GET /knowledgebases('{name}')`
- **Operation ID**: KnowledgeBases_Get
- **Description**: Retrieves a knowledge base by name
- **Parameters**: name (path, required)
- **Response**: KnowledgeBase
- **SDK Method**: `SearchIndexClient.GetKnowledgeBase(string name)`

## New Models

### KnowledgeBase
- **Description**: Represents a knowledge base for AI-powered search
- **Properties**:
  - `name` (string, required): The name of the knowledge base
  - `description` (string, optional): A description
  - `sources` (KnowledgeSource[], required): Knowledge sources
- **SDK Class**: `Azure.Search.Documents.Indexes.Models.KnowledgeBase`

### KnowledgeSource
- **Description**: A source of knowledge for the knowledge base
- **Properties**:
  - `type` (KnowledgeSourceKind, required): The type of source
  - `connectionString` (string, optional): Connection information
- **SDK Class**: `Azure.Search.Documents.Indexes.Models.KnowledgeSource`

## Modified Models

### SearchIndex
- **Added Properties**:
  - `description` (string, optional): A textual description of the index
- **SDK Impact**: Add new property to existing class

### VectorSearchCompression
- **Added Properties**:
  - `rescoringOptions` (RescoringOptions, optional): Options for rescoring
- **Removed Properties**:
  - `rerankWithOriginalVectors` (moved to RescoringOptions)
- **SDK Impact**: Add new property, mark old property as obsolete

## Breaking Changes

### Removed: KnowledgeAgent → KnowledgeBase
- **Change**: `KnowledgeAgent*` types renamed to `KnowledgeBase*`
- **Migration**: Update all references from Agent to Base
- **SDK Impact**:
  - Rename classes
  - Update client methods
  - Add migration notes to CHANGELOG

## New Enums

### KnowledgeSourceKind
- `web`: Web-based knowledge source
- `sharepoint`: SharePoint knowledge source
- `blob`: Azure Blob storage source
- **SDK Enum**: `Azure.Search.Documents.Indexes.Models.KnowledgeSourceKind`

## SDK Implementation Checklist

### autorest.md Updates
- [ ] Update input-file URLs to new commit
- [ ] Add rename directives for model changes
- [ ] Add suppress directives for abstract classes

### New Types to Generate
- [ ] KnowledgeBase
- [ ] KnowledgeSource
- [ ] KnowledgeSourceKind
- [ ] RescoringOptions

### Customizations Needed
- [ ] CodeGenModel for KnowledgeBase types
- [ ] Extension methods for new operations
- [ ] Model factory updates

### Tests to Add/Update
- [ ] KnowledgeBaseClientTests
- [ ] VectorSearchCompressionTests (for rescoring)
- [ ] Update existing tests for model changes

### Documentation
- [ ] CHANGELOG.md entries
- [ ] README.md updates for new features
- [ ] XML documentation for new types
```

---

## Step 7: Pass to SDK-Release Skill

### Goal
Provide the change summary as context for SDK implementation via the shared references folder.

### Automatic Integration

When you run `Generate-ChangeSummary.ps1`, the analysis is automatically saved to:
```
.github/skills/azure-search-sdk-release/references/API-ANALYSIS-{api-version}.md
```

The SDK-release skill will automatically detect and read this file in its Step 0.

### Verify the Output

```powershell
# Confirm the analysis was written
$refsPath = "c:\azure-sdk-for-net\.github\skills\azure-search-sdk-release\references"
Get-ChildItem -Path $refsPath -Filter "API-ANALYSIS-*.md"

# View the contents
Get-Content (Join-Path $refsPath "API-ANALYSIS-2025-11-01-preview.md")
```

### Handoff Format

The analysis file contains:

1. **Metadata Section**: Commit SHAs, API version, analysis date
2. **Summary Statistics**: Counts of new/removed operations, models, properties
3. **Detailed Changes**: Each new operation, model, and property with descriptions
4. **Breaking Changes**: Items removed that need migration notes
5. **SDK Implementation Checklist**: Tasks for autorest.md, customizations, tests
6. **Suggested CHANGELOG Entry**: Pre-written changelog to adapt

### Example Handoff

```markdown
## SDK Release Context

### Commits
- Previous: `abc123def456...`
- New: `789xyz012...`
- API Version: `2025-11-01-preview`

### Priority 1: Breaking Changes
1. Rename KnowledgeAgent → KnowledgeBase throughout
2. Move rerankWithOriginalVectors to RescoringOptions

### Priority 2: New Features
1. Add KnowledgeBase types and operations
2. Add SearchIndex.description property
3. Add new KnowledgeSourceKind enum values

### Priority 3: Customizations
1. Update autorest.md with new directives
2. Add CodeGenModel mappings for renamed types
3. Update SearchModelFactory with new methods

### Suggested CHANGELOG Entry
```
## 11.8.0-beta.2 (Unreleased)

### Features Added
- Added support for `2025-11-01-preview` service version.
- Added `KnowledgeBase` and related types for AI-powered search.
- Added `SearchIndex.Description` property.
- Added `RescoringOptions` for vector search compression.

### Breaking Changes
- Renamed `KnowledgeAgent*` classes to `KnowledgeBase*`.
- Moved `VectorSearchCompression.RerankWithOriginalVectors` to `RescoringOptions.EnabledRescoring`.
```
```

---

## Quick Reference: Swagger Analysis Commands

### Compare All Definitions
```powershell
# Get definition names
$prevDefs = (Get-Content previous.json | ConvertFrom-Json).definitions.PSObject.Properties.Name
$newDefs = (Get-Content new.json | ConvertFrom-Json).definitions.PSObject.Properties.Name

# New definitions
$newDefs | Where-Object { $_ -notin $prevDefs }

# Removed definitions
$prevDefs | Where-Object { $_ -notin $newDefs }
```

### Compare Properties of a Model
```powershell
$model = "SearchIndex"
$prevProps = (Get-Content previous.json | ConvertFrom-Json).definitions.$model.properties.PSObject.Properties.Name
$newProps = (Get-Content new.json | ConvertFrom-Json).definitions.$model.properties.PSObject.Properties.Name

# New properties
$newProps | Where-Object { $_ -notin $prevProps }
```

### Find All Operations
```powershell
$swagger = Get-Content searchservice.json | ConvertFrom-Json
$swagger.paths.PSObject.Properties | ForEach-Object {
    $path = $_.Name
    $_.Value.PSObject.Properties | Where-Object { $_.Name -in @('get','post','put','delete','patch') } | ForEach-Object {
        "$($_.Name.ToUpper()) $path - $($_.Value.operationId)"
    }
}
```

---

## References

- [Swagger Analysis Guide](references/SWAGGER-ANALYSIS.md)
- [Change Classification Guide](references/CHANGE-CLASSIFICATION.md)
- [SDK Mapping Patterns](references/SDK-MAPPING.md)
- [OpenAPI Specification](https://swagger.io/specification/v2/)
- [Azure REST API Guidelines](https://github.com/microsoft/api-guidelines/blob/vNext/azure/Guidelines.md)
