# Azure Search SDK Code Generation Reference

This document provides detailed technical reference for the Azure.Search.Documents SDK code generation process.

## AutoRest Configuration

The SDK uses AutoRest for code generation with customizations defined in `autorest.md`.

### Input Files

The SDK is generated from three swagger files:
- `searchindex.json` - Search, Autocomplete, Suggest, and Document operations
- `searchservice.json` - Index, Indexer, Skillset, DataSource, SynonymMap, Alias management
- `knowledgebase.json` - Knowledge Base operations (added in 2025-05-01-preview)

### Key Configuration Options

```yaml
use-model-reader-writer: true          # Enable System.ClientModel serialization
generation1-convenience-client: true   # Generate convenience client methods
deserialize-null-collection-as-null-value: true  # Handle null collections
```

## Customization Directives

### Removing Operations

Remove unwanted operations from the generated client:
```yaml
directive:
- remove-operation: Documents_AutocompleteGet
- remove-operation: Documents_SearchGet
- remove-operation: Documents_SuggestGet
```

### Suppressing Abstract Base Classes

Prevent generation of abstract base classes:
```yaml
suppress-abstract-base-class:
- CharFilter
- CognitiveServicesAccount
- LexicalAnalyzer
- SearchIndexerSkill
```

### Renaming Types

Rename generated types to follow SDK naming conventions:
```yaml
directive:
- from: "searchservice.json"
  where: $.definitions.OldTypeName
  transform: $["x-ms-client-name"] = "NewTypeName";
```

### Making Types Internal

Hide implementation types from public API:
```yaml
directive:
- from: searchservice.json
  where: $.definitions.TypeName
  transform: $["x-accessibility"] = "internal"
```

### Moving Types to Different Namespaces

```yaml
directive:
  from: knowledgebase.json
  where: $.definitions.*
  transform: >
    $["x-namespace"] = "Azure.Search.Documents.KnowledgeBases.Models"
```

### Modifying Properties

Add, remove, or modify properties on generated types:
```yaml
directive:
- from: "searchservice.json"
  where: $.definitions.TypeName
  transform: >
    $.properties.newProperty = {
      "type": "boolean",
      "description": "Description of the property",
      "x-nullable": true
    };
```

### Adding Format Annotations

```yaml
directive:
- from: searchindex.json
  where: $.definitions.TypeName.properties.propertyName
  transform: $.format = "url"
```

### Enabling Embedding Vector Support

```yaml
directive:
- from: searchindex.json
  where: $.definitions.RawVectorQuery.properties.vector
  transform: $["x-ms-embedding-vector"] = true;
```

## Model Customization Patterns

### CodeGenModel Attribute

Use `[CodeGenModel]` to map custom types to generated types:

```csharp
// Hide the generated type
[CodeGenModel("GeneratedName")]
internal partial class GeneratedName { }

// Create public replacement with generic support
public class CustomName<T>
{
    // Custom implementation
}
```

### Partial Classes

Extend generated types with additional functionality:

```csharp
namespace Azure.Search.Documents.Models
{
    public partial class GeneratedModel
    {
        // Add custom constructors
        public GeneratedModel(string customParam)
        {
            // Custom initialization
        }

        // Add custom properties
        public string CustomProperty => ComputeValue();

        // Add custom methods
        public void CustomMethod() { }
    }
}
```

### Model Factory Updates

Add factory methods for testability:

```csharp
public static partial class SearchModelFactory
{
    public static NewModel NewModel(
        string property1 = default,
        int property2 = default)
    {
        return new NewModel(property1, property2);
    }
}
```

## Namespace Organization

| Namespace | Content |
|-----------|---------|
| `Azure.Search.Documents` | Client classes, options |
| `Azure.Search.Documents.Models` | Search/Query models |
| `Azure.Search.Documents.Indexes` | Index client classes |
| `Azure.Search.Documents.Indexes.Models` | Index/Indexer models |
| `Azure.Search.Documents.KnowledgeBases` | Knowledge Base clients |
| `Azure.Search.Documents.KnowledgeBases.Models` | Knowledge Base models |

## Version Support Matrix

| SDK Version | Stable API | Preview API |
|-------------|------------|-------------|
| 11.7.0 | 2025-09-01 | - |
| 11.8.0-beta.1 | - | 2025-11-01-preview |

## Generated Files

The following directories contain generated code:
- `src/Generated/` - REST clients and internal types
- `src/Generated/Models/` - Model classes
- `src/Generated/Internal/` - Internal helper types

**Never edit files in Generated folders directly.**

## Build Targets

| Command | Description |
|---------|-------------|
| `dotnet build /t:GenerateCode` | Regenerate from swagger |
| `dotnet build` | Build the project |
| `dotnet test` | Run all tests |
| `dotnet pack` | Create NuGet package |
