# C# Coding Standards for Azure SDK

This document outlines the C# coding standards that apply to the Azure.Search.Documents SDK.

## Naming Conventions

### Types

| Element | Convention | Example |
|---------|------------|---------|
| Class | PascalCase | `SearchClient` |
| Interface | IPascalCase | `ISearchDocument` |
| Struct | PascalCase | `SearchAudience` |
| Enum | PascalCase | `SearchMode` |
| Enum member | PascalCase | `All`, `Any` |
| Delegate | PascalCase | `SearchEventHandler` |

### Members

| Element | Convention | Example |
|---------|------------|---------|
| Method | PascalCase | `GetDocument()` |
| Async method | PascalCaseAsync | `GetDocumentAsync()` |
| Property | PascalCase | `Endpoint` |
| Event | PascalCase | `DocumentUploaded` |
| Constant | PascalCase | `MaxRetries` |
| Public field | PascalCase | `DefaultValue` |
| Private field | _camelCase | `_httpClient` |
| Parameter | camelCase | `cancellationToken` |
| Local variable | camelCase | `searchResults` |

### Special Conventions

```csharp
// Boolean properties use Is/Has/Can/Should prefixes
public bool IsEnabled { get; set; }
public bool HasValue { get; }
public bool CanRetry { get; }

// Factory methods use Create/From prefixes
public static SearchClient CreateFromConnectionString(string connectionString)

// Try pattern for optional returns
public bool TryGetValue(string key, out T value)
```

## Documentation Standards

### All Public APIs Must Have XML Documentation

```csharp
/// <summary>
/// Searches for documents in the search index.
/// </summary>
/// <typeparam name="T">
/// The .NET type that maps to the index schema.
/// </typeparam>
/// <param name="searchText">
/// The search text to query. Use "*" to match all documents.
/// </param>
/// <param name="options">
/// Options to customize the search behavior.
/// </param>
/// <param name="cancellationToken">
/// A <see cref="CancellationToken"/> controlling the request lifetime.
/// </param>
/// <returns>
/// A <see cref="Response{T}"/> containing the search results.
/// </returns>
/// <exception cref="RequestFailedException">
/// Thrown when a failure is returned by the Search service.
/// </exception>
public virtual Response<SearchResults<T>> Search<T>(
    string searchText,
    SearchOptions options = null,
    CancellationToken cancellationToken = default)
```

### Documentation Requirements

| Element | Required Tags |
|---------|---------------|
| Type | `<summary>` |
| Method | `<summary>`, `<param>` for each, `<returns>`, `<exception>` |
| Property | `<summary>` |
| Parameter type | `<typeparam>` |
| Enum member | `<summary>` |

## Azure SDK Patterns

### Client Constructors

```csharp
public partial class SearchClient
{
    // Protected parameterless for mocking
    protected SearchClient() { }

    // API key authentication
    public SearchClient(Uri endpoint, string indexName, AzureKeyCredential credential) { }
    public SearchClient(Uri endpoint, string indexName, AzureKeyCredential credential, SearchClientOptions options) { }

    // Token credential authentication
    public SearchClient(Uri endpoint, string indexName, TokenCredential tokenCredential) { }
    public SearchClient(Uri endpoint, string indexName, TokenCredential tokenCredential, SearchClientOptions options) { }
}
```

### Method Signatures

```csharp
// Standard async pattern
public virtual async Task<Response<T>> OperationAsync(
    RequiredParam required,
    OptionalOptions options = null,
    CancellationToken cancellationToken = default)

// Sync variant
public virtual Response<T> Operation(
    RequiredParam required,
    OptionalOptions options = null,
    CancellationToken cancellationToken = default)
```

### Response Types

```csharp
// Single item
Response<SearchIndex> GetIndex(string indexName);

// Collection (not async enumerable)
Response<IReadOnlyList<SearchIndex>> GetIndexes();

// Paged results (async enumerable)
AsyncPageable<SearchResult<T>> Search<T>(string searchText);
Pageable<SearchResult<T>> Search<T>(string searchText);
```

### Options Classes

```csharp
public class SearchOptions
{
    // Parameterless constructor
    public SearchOptions() { }

    // Simple properties
    public string Filter { get; set; }
    public int? Size { get; set; }

    // Collection properties (never null)
    public IList<string> SearchFields { get; }
    public IList<string> Select { get; }
}
```

## Code Quality Rules

### Nullable Reference Types

```csharp
// Enable nullable in project
#nullable enable

// Annotate properly
public string? OptionalProperty { get; set; }  // Can be null
public string RequiredProperty { get; }         // Cannot be null

// Handle nullability in methods
public void Process(string? input)
{
    if (input is null)
        throw new ArgumentNullException(nameof(input));
}
```

### Exception Handling

```csharp
// Use RequestFailedException for service errors
catch (RequestFailedException ex) when (ex.Status == 404)
{
    // Handle not found
}

// Validate arguments
public void Method(string required, int count)
{
    Argument.AssertNotNullOrEmpty(required, nameof(required));
    Argument.AssertInRange(count, 0, 1000, nameof(count));
}
```

### Async Best Practices

```csharp
// Always forward CancellationToken
public async Task<Response<T>> GetAsync(CancellationToken cancellationToken = default)
{
    return await _pipeline.SendRequestAsync(request, cancellationToken).ConfigureAwait(false);
}

// Use ConfigureAwait(false) in library code
await SomeAsyncOperation().ConfigureAwait(false);

// Never use .Result or .Wait() - causes deadlocks
// BAD: var result = GetAsync().Result;
// GOOD: var result = await GetAsync();
```

## Generated Code Rules

### Never Edit Generated Files

Files in `Generated/` folders are auto-generated. All customizations must be done via:

1. **Partial classes** in separate files
2. **Directives in autorest.md**
3. **CodeGenModel attributes**

### Customization Patterns

```csharp
// In src/Models/CustomModel.cs (NOT in Generated/)
namespace Azure.Search.Documents.Models
{
    // Extend generated partial class
    public partial class GeneratedModel
    {
        // Add custom functionality
        public string ComputedProperty => $"{Prop1}-{Prop2}";
    }
}

// Hide and replace generated type
[CodeGenModel("InternalGeneratedName")]
internal partial class InternalGeneratedName { }

public class PublicCustomName
{
    // Custom implementation
}
```

## File Organization

### One Type Per File (Usually)

```
src/
├── SearchClient.cs           # Main client
├── SearchClientOptions.cs    # Options class
├── Models/
│   ├── SearchResult.cs       # Each model in own file
│   └── SearchOptions.cs
└── Generated/                # Auto-generated (don't edit)
    └── Models/
```

### Using Statements

```csharp
// System namespaces first
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

// Azure namespaces
using Azure;
using Azure.Core;
using Azure.Core.Pipeline;

// Project namespaces
using Azure.Search.Documents.Models;
```

## Code Review Checklist

### Must Pass

- [ ] All public APIs have XML documentation
- [ ] Async methods have sync counterparts
- [ ] Methods end with `Async` suffix where appropriate
- [ ] `CancellationToken` is last parameter with default
- [ ] No compiler warnings
- [ ] No manual edits to `Generated/` folder
- [ ] Nullable annotations are correct

### Should Review

- [ ] Naming follows conventions
- [ ] Exception handling is appropriate
- [ ] Performance considerations addressed
- [ ] Thread-safety documented if relevant
