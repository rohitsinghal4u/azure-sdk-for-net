# API Comparison Guide

This document provides detailed guidance on comparing Azure.Search.Documents API surfaces between versions.

## API Export Files

The SDK maintains public API surface files for each target framework:

```
sdk/search/Azure.Search.Documents/api/
├── Azure.Search.Documents.net8.0.cs      # .NET 8.0 API surface
├── Azure.Search.Documents.net10.0.cs     # .NET 10.0 API surface
└── Azure.Search.Documents.netstandard2.0.cs  # .NET Standard 2.0 API surface
```

## Understanding the API Format

### Type Declarations

```csharp
// Partial class with interfaces
public partial class SearchClient

// Struct with layout
[System.Runtime.InteropServices.StructLayoutAttribute(...)]
public readonly partial struct SearchAudience : System.IEquatable<...>

// Enum
public enum ServiceVersion
```

### Member Declarations

```csharp
// Constructor
public SearchClient(System.Uri endpoint, string indexName, Azure.AzureKeyCredential credential) { }

// Property with getter/setter
public string Filter { get { throw null; } set { } }

// Read-only property
public virtual System.Uri Endpoint { get { throw null; } }

// Method
public virtual Azure.Response<T> GetDocument<T>(...) { throw null; }

// Async method
public virtual System.Threading.Tasks.Task<Azure.Response<T>> GetDocumentAsync<T>(...) { throw null; }
```

### Interface Implementations

```csharp
// Explicit interface implementation (internal detail)
Azure.Search.Documents.AutocompleteOptions System.ClientModel.Primitives.IJsonModel<...>.Create(...) { throw null; }
```

## Extracting Previous API

### From a Specific Commit

```powershell
# Get API file from previous commit
$previousCommit = "abc123def456"
git show ${previousCommit}:sdk/search/Azure.Search.Documents/api/Azure.Search.Documents.net8.0.cs > previous-api.cs
```

### From a Tag

```powershell
# Get API from a release tag
$tag = "Azure.Search.Documents_11.7.0"
git show ${tag}:sdk/search/Azure.Search.Documents/api/Azure.Search.Documents.net8.0.cs > previous-api.cs
```

### From a Branch

```powershell
# Get API from main branch
git show main:sdk/search/Azure.Search.Documents/api/Azure.Search.Documents.net8.0.cs > previous-api.cs
```

## Comparison Techniques

### Visual Diff

```powershell
# Using git diff
git diff --no-index --color previous-api.cs current-api.cs

# Using VS Code
code --diff previous-api.cs current-api.cs
```

### Programmatic Comparison

```powershell
# PowerShell comparison
$previous = Get-Content previous-api.cs
$current = Get-Content sdk/search/Azure.Search.Documents/api/Azure.Search.Documents.net8.0.cs

# Find additions (in current but not previous)
$additions = Compare-Object $previous $current | Where-Object { $_.SideIndicator -eq '=>' }

# Find removals (in previous but not current)
$removals = Compare-Object $previous $current | Where-Object { $_.SideIndicator -eq '<=' }
```

## Categorizing Changes

### Additive Changes (Safe)

These are backwards-compatible additions:

| Change | Example |
|--------|---------|
| New public class | `public partial class NewFeature { }` |
| New public method | `public void NewMethod() { }` |
| New public property | `public string NewProperty { get; set; }` |
| New optional parameter | `public void Method(int x, int y = 0)` |
| New enum value | `NewValue = 5,` |
| New interface implementation | `INewInterface` |

### Breaking Changes (Requires Justification)

These require documentation and review:

| Change | Impact |
|--------|--------|
| Removed public type | Binary breaking |
| Removed public member | Binary breaking |
| Changed method signature | Binary breaking |
| Changed property type | Binary breaking |
| Changed return type | Binary breaking |
| Added required parameter | Source breaking |
| Changed inheritance | Binary breaking |
| Sealed previously unsealed type | Binary breaking |
| Made type abstract | Binary breaking |

### Neutral Changes

These don't affect compatibility:

| Change | Notes |
|--------|-------|
| Internal member changes | Not part of public API |
| XML comment updates | Documentation only |
| Explicit interface changes | Implementation detail |
| Reordering members | Same API surface |

## Parsing API Declarations

### Extract Types

```powershell
# Find all public types
$types = Select-String -Path current-api.cs -Pattern "^\s*public\s+(partial\s+)?(class|struct|interface|enum)\s+(\w+)" |
    ForEach-Object { $_.Matches.Groups[3].Value }
```

### Extract Methods

```powershell
# Find all public methods
$methods = Select-String -Path current-api.cs -Pattern "public\s+(virtual\s+|static\s+|abstract\s+)*\S+\s+(\w+)\s*\(" |
    ForEach-Object { $_.Matches.Groups[2].Value }
```

### Extract Properties

```powershell
# Find all public properties
$properties = Select-String -Path current-api.cs -Pattern "public\s+\S+\s+(\w+)\s*\{" |
    ForEach-Object { $_.Matches.Groups[1].Value }
```

## Framework-Specific Differences

### .NET Standard 2.0 vs .NET 8.0

Some APIs may differ between frameworks:

```csharp
// .NET 8.0+ only - uses newer features
public virtual System.Threading.Tasks.Task<Response<T>> SearchAsync<T>(
    string searchText,
    System.Text.Json.Serialization.Metadata.JsonTypeInfo<T> typeInfo, ...)

// Both frameworks - standard pattern
public virtual System.Threading.Tasks.Task<Response<T>> SearchAsync<T>(
    string searchText,
    SearchOptions options = null, ...)
```

Review all framework API files when checking compatibility.

## Common Patterns to Watch

### ServiceVersion Enum

```csharp
public enum ServiceVersion
{
    V2020_06_30 = 1,
    V2023_11_01 = 2,
    V2024_07_01 = 3,
    V2025_09_01 = 4,           // Latest stable
    V2025_11_01_Preview = 5,   // Latest preview
}
```

New versions should:
- Use incrementing integer values
- Follow naming convention `V{YYYY}_{MM}_{DD}[_Preview]`
- Update `LatestVersion` constant if newest

### Model Factory Methods

```csharp
public static partial class SearchModelFactory
{
    public static SearchResult<T> SearchResult<T>(
        T document = default,
        double? score = default,
        ...) { throw null; }
}
```

All public models should have corresponding factory methods.

### Async/Sync Pairs

Every async method should have a sync counterpart:

```csharp
// Async variant
public virtual Task<Response<T>> GetDocumentAsync<T>(..., CancellationToken cancellationToken = default) { }

// Sync variant
public virtual Response<T> GetDocument<T>(..., CancellationToken cancellationToken = default) { }
```
